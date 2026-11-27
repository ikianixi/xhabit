package app.xhabit.nativebridge;

import android.content.ContentResolver;
import android.content.ContentValues;
import android.content.Context;
import android.content.pm.PackageInfo;
import android.database.Cursor;
import android.net.Uri;
import android.os.Build;
import android.os.Environment;
import android.os.Handler;
import android.os.Looper;
import android.provider.DocumentsContract;
import android.provider.MediaStore;

import androidx.annotation.NonNull;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.TimeZone;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

/**
 * Registers app.xhabit.tracker/storage on every FlutterEngine (main Activity as well as
 * headless Workmanager, HomeWidget, and local notification background isolates).
 */
public class XHabitNativePlugin implements FlutterPlugin, MethodChannel.MethodCallHandler {
    private static final String CHANNEL_NAME = "app.xhabit.tracker/storage";

    private Context appContext;
    private MethodChannel channel;
    private ExecutorService ioExecutor;
    private Handler mainHandler;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        appContext = binding.getApplicationContext();
        ioExecutor = Executors.newSingleThreadExecutor();
        mainHandler = new Handler(Looper.getMainLooper());
        channel = new MethodChannel(binding.getBinaryMessenger(), CHANNEL_NAME);
        channel.setMethodCallHandler(this);
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        if (channel != null) {
            channel.setMethodCallHandler(null);
            channel = null;
        }
        if (ioExecutor != null) {
            ioExecutor.shutdown();
            ioExecutor = null;
        }
        appContext = null;
    }

    private void postSuccess(@NonNull final MethodChannel.Result result, final Object value) {
        final Handler handler = mainHandler;
        if (handler != null) {
            handler.post(() -> result.success(value));
        } else {
            result.success(value);
        }
    }

    @Override
    @SuppressWarnings("unchecked")
    public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        final Context ctx = appContext;
        if (ctx == null) {
            result.success(null);
            return;
        }

        switch (call.method) {
            case "getLocalTimezone":
                result.success(TimeZone.getDefault().getID());
                break;

            case "getAppVersion": {
                try {
                    PackageInfo pInfo = ctx.getPackageManager().getPackageInfo(ctx.getPackageName(), 0);
                    long vCode = Build.VERSION.SDK_INT >= Build.VERSION_CODES.P
                            ? pInfo.getLongVersionCode()
                            : (long) pInfo.versionCode;
                    Map<String, Object> out = new HashMap<>();
                    out.put("versionName", pInfo.versionName != null ? pInfo.versionName : "1.0.0");
                    out.put("versionCode", (int) vCode);
                    result.success(out);
                } catch (Throwable t) {
                    result.success(null);
                }
                break;
            }

            case "saveToDownloads": {
                final String fileName = call.argument("fileName") != null
                        ? (String) call.argument("fileName")
                        : "xhabit_backup.json";
                final byte[] bytes = call.argument("bytes");
                final String mimeType = call.argument("mimeType") != null
                        ? (String) call.argument("mimeType")
                        : "application/json";
                if (bytes == null) {
                    result.success(null);
                    return;
                }
                ioExecutor.execute(() -> {
                    String out = null;
                    try {
                        out = saveBytesToDownloads(ctx, fileName, bytes, mimeType);
                    } catch (Throwable ignored) {
                    }
                    postSuccess(result, out);
                });
                break;
            }

            case "syncOrganizedData": {
                final String readableJson = call.argument("readableJson") != null
                        ? (String) call.argument("readableJson")
                        : "{}";
                final String sqliteDbPath = call.argument("sqliteDbPath") != null
                        ? (String) call.argument("sqliteDbPath")
                        : "";
                final List<String> mediaPaths = call.argument("mediaPaths") != null
                        ? (List<String>) call.argument("mediaPaths")
                        : new ArrayList<>();
                final String customTreeUri = call.argument("customTreeUri");
                ioExecutor.execute(() -> {
                    String savedLoc = null;
                    try {
                        savedLoc = syncOrganizedStructure(
                                ctx, readableJson, sqliteDbPath, mediaPaths, customTreeUri);
                    } catch (Throwable ignored) {
                    }
                    postSuccess(result, savedLoc);
                });
                break;
            }

            case "writeRelativeFiles": {
                final String treeUriStr = call.argument("treeUri") != null
                        ? (String) call.argument("treeUri")
                        : "";
                final String rootFolder = call.argument("rootFolder") != null
                        ? (String) call.argument("rootFolder")
                        : "XHabit";
                final List<Map<String, Object>> files = call.argument("files") != null
                        ? (List<Map<String, Object>>) call.argument("files")
                        : new ArrayList<>();
                if (treeUriStr.trim().isEmpty() || rootFolder.trim().isEmpty()) {
                    result.success(0);
                    return;
                }
                ioExecutor.execute(() -> {
                    int written = 0;
                    try {
                        ContentResolver cr = ctx.getContentResolver();
                        Uri treeUri = Uri.parse(treeUriStr);
                        String rootDocId = DocumentsContract.getTreeDocumentId(treeUri);
                        Uri rootDocUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, rootDocId);
                        Uri appFolder = findOrCreateSafSubdir(cr, treeUri, rootDocUri, rootFolder);
                        if (appFolder == null) {
                            throw new IllegalStateException("Failed to resolve SAF root folder");
                        }
                        for (Map<String, Object> item : files) {
                            String sub = item.get("subDir") instanceof String ? (String) item.get("subDir") : "";
                            Object fnObj = item.get("fileName");
                            if (!(fnObj instanceof String)) continue;
                            String fileName = (String) fnObj;
                            String mime = item.get("mimeType") instanceof String
                                    ? (String) item.get("mimeType")
                                    : "text/plain";
                            String content = item.get("content") instanceof String
                                    ? (String) item.get("content")
                                    : "";
                            Uri targetDir = sub.isEmpty()
                                    ? appFolder
                                    : resolveOrCreatePath(cr, treeUri, appFolder, sub);
                            if (targetDir == null) continue;
                            byte[] bytes = content.getBytes(StandardCharsets.UTF_8);
                            if (writeSafBytes(cr, treeUri, targetDir, fileName, mime, bytes, null)) {
                                written++;
                            }
                        }
                    } catch (Throwable ignored) {
                        written = 0;
                    }
                    postSuccess(result, written);
                });
                break;
            }

            case "syncRelativeFiles": {
                final String treeUriStr = call.argument("treeUri") != null
                        ? (String) call.argument("treeUri")
                        : "";
                final String rootFolder = call.argument("rootFolder") != null
                        ? (String) call.argument("rootFolder")
                        : "XHabit";
                final List<Map<String, Object>> files = call.argument("files") != null
                        ? (List<Map<String, Object>>) call.argument("files")
                        : new ArrayList<>();
                final List<String> keepPaths = call.argument("keepRelativePaths");
                if (treeUriStr.trim().isEmpty() || rootFolder.trim().isEmpty()) {
                    result.success(-1);
                    return;
                }
                ioExecutor.execute(() -> {
                    int written;
                    try {
                        ContentResolver cr = ctx.getContentResolver();
                        Uri treeUri = Uri.parse(treeUriStr);
                        String rootDocId = DocumentsContract.getTreeDocumentId(treeUri);
                        Uri rootDocUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, rootDocId);
                        Uri appFolder = findOrCreateSafSubdir(cr, treeUri, rootDocUri, rootFolder);
                        if (appFolder == null) {
                            throw new IllegalStateException("Failed to resolve SAF root folder");
                        }
                        written = syncSafRelativeTree(cr, treeUri, appFolder, files, keepPaths);
                    } catch (Throwable ignored) {
                        written = -1;
                    }
                    postSuccess(result, written);
                });
                break;
            }

            case "deleteRelativeFolder": {
                final String treeUriStr = call.argument("treeUri") != null
                        ? (String) call.argument("treeUri")
                        : "";
                final String rootFolder = call.argument("rootFolder") != null
                        ? (String) call.argument("rootFolder")
                        : "XHabit";
                if (treeUriStr.trim().isEmpty()
                        || rootFolder.trim().isEmpty()
                        || "/".equals(rootFolder)
                        || ".".equals(rootFolder)) {
                    result.success(false);
                    return;
                }
                ioExecutor.execute(() -> {
                    boolean deleted;
                    try {
                        ContentResolver cr = ctx.getContentResolver();
                        Uri treeUri = Uri.parse(treeUriStr);
                        String rootDocId = DocumentsContract.getTreeDocumentId(treeUri);
                        Uri rootDocUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, rootDocId);
                        Uri target = findExistingSafSubdir(cr, treeUri, rootDocUri, rootFolder);
                        deleted = target == null || DocumentsContract.deleteDocument(cr, target);
                    } catch (Throwable ignored) {
                        deleted = false;
                    }
                    postSuccess(result, deleted);
                });
                break;
            }

            default:
                result.notImplemented();
                break;
        }
    }

    private String saveBytesToDownloads(
            Context ctx,
            String fileName,
            byte[] bytes,
            String mimeType
    ) throws IOException {
        ContentResolver cr = ctx.getContentResolver();
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ContentValues values = new ContentValues();
            values.put(MediaStore.Downloads.DISPLAY_NAME, fileName);
            values.put(MediaStore.Downloads.MIME_TYPE, mimeType);
            values.put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/XHabit");
            values.put(MediaStore.Downloads.IS_PENDING, 1);
            Uri uri = cr.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values);
            if (uri == null) return null;
            try (OutputStream out = cr.openOutputStream(uri)) {
                if (out == null) return null;
                out.write(bytes);
            }
            values.clear();
            values.put(MediaStore.Downloads.IS_PENDING, 0);
            cr.update(uri, values, null, null);
            return "Download/XHabit/" + fileName;
        } else {
            @SuppressWarnings("deprecation")
            File dlDir = new File(
                    Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
                    "XHabit");
            if (!dlDir.exists()) dlDir.mkdirs();
            File outFile = new File(dlDir, fileName);
            try (FileOutputStream fos = new FileOutputStream(outFile)) {
                fos.write(bytes);
            }
            return outFile.getAbsolutePath();
        }
    }

    private String syncOrganizedStructure(
            Context ctx,
            String readableJson,
            String sqliteDbPath,
            List<String> mediaPaths,
            String customTreeUri
    ) throws IOException {
        File extRoot = ctx.getExternalFilesDir(null);
        File baseExternal = new File(extRoot != null ? extRoot : ctx.getFilesDir(), "XHabit");
        File dbDir = new File(baseExternal, "Database");
        File bkDir = new File(baseExternal, "Backups");
        File medDir = new File(baseExternal, "Media");
        File expDir = new File(baseExternal, "Exports");
        dbDir.mkdirs();
        bkDir.mkdirs();
        medDir.mkdirs();
        expDir.mkdirs();

        byte[] jsonBytes = readableJson.getBytes(StandardCharsets.UTF_8);
        writeFileBytes(new File(dbDir, "xhabit_data.json"), jsonBytes);
        writeFileBytes(new File(bkDir, "latest_backup.json"), jsonBytes);

        File dbFile = new File(sqliteDbPath);
        if (dbFile.exists()) {
            copyFile(dbFile, new File(dbDir, "xhabit.sqlite"));
        }
        for (String mPath : mediaPaths) {
            File src = new File(mPath);
            if (src.exists()) {
                copyFile(src, new File(medDir, src.getName()));
            }
        }

        if (customTreeUri != null && !customTreeUri.trim().isEmpty()) {
            try {
                writeIntoSafTree(ctx.getContentResolver(), Uri.parse(customTreeUri), jsonBytes, dbFile, mediaPaths);
                return customTreeUri;
            } catch (Throwable ignored) {
            }
        }
        return baseExternal.getAbsolutePath();
    }

    private void writeFileBytes(File target, byte[] bytes) throws IOException {
        try (FileOutputStream fos = new FileOutputStream(target)) {
            fos.write(bytes);
        }
    }

    private void copyFile(File src, File dst) throws IOException {
        try (InputStream in = new FileInputStream(src);
             OutputStream out = new FileOutputStream(dst)) {
            copyStream(in, out);
        }
    }

    private void copyStream(InputStream in, OutputStream out) throws IOException {
        byte[] buf = new byte[8192];
        int len;
        while ((len = in.read(buf)) != -1) {
            out.write(buf, 0, len);
        }
    }

    private void writeIntoSafTree(
            ContentResolver cr,
            Uri treeUri,
            byte[] jsonBytes,
            File dbFile,
            List<String> mediaPaths
    ) throws IOException {
        String rootDocId = DocumentsContract.getTreeDocumentId(treeUri);
        Uri rootDocUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, rootDocId);
        Uri appFolder = findOrCreateSafSubdir(cr, treeUri, rootDocUri, "XHabit");
        if (appFolder == null) return;
        Uri dbSub = findOrCreateSafSubdir(cr, treeUri, appFolder, "Database");
        Uri bkSub = findOrCreateSafSubdir(cr, treeUri, appFolder, "Backups");
        Uri medSub = findOrCreateSafSubdir(cr, treeUri, appFolder, "Media");
        if (dbSub == null || bkSub == null || medSub == null) return;
        findOrCreateSafSubdir(cr, treeUri, appFolder, "Exports");

        writeSafBytes(cr, treeUri, dbSub, "xhabit_data.json", "application/json", jsonBytes, null);
        writeSafBytes(cr, treeUri, bkSub, "latest_backup.json", "application/json", jsonBytes, null);
        if (dbFile.exists()) {
            writeSafFileStream(cr, treeUri, dbSub, "xhabit.sqlite", "application/octet-stream", dbFile);
        }
        for (String mPath : mediaPaths) {
            File src = new File(mPath);
            if (src.exists()) {
                writeSafFileStream(cr, treeUri, medSub, src.getName(), "application/octet-stream", src);
            }
        }
    }

    private Uri resolveOrCreatePath(
            ContentResolver cr,
            Uri treeUri,
            Uri appFolder,
            String subDir
    ) {
        Uri cur = appFolder;
        String clean = trimSlashes(subDir);
        if (clean.isEmpty()) return appFolder;
        for (String seg : clean.split("/")) {
            if (seg.isEmpty()) continue;
            cur = findOrCreateSafSubdir(cr, treeUri, cur, seg);
            if (cur == null) return null;
        }
        return cur;
    }

    private String trimSlashes(String s) {
        int start = 0;
        int end = s.length();
        while (start < end && s.charAt(start) == '/') start++;
        while (end > start && s.charAt(end - 1) == '/') end--;
        return s.substring(start, end);
    }

    private Uri findExistingSafSubdir(ContentResolver cr, Uri treeUri, Uri parentDocUri, String name) {
        Uri childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(
                treeUri, DocumentsContract.getDocumentId(parentDocUri));
        String[] proj = new String[]{
                DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                DocumentsContract.Document.COLUMN_MIME_TYPE
        };
        try (Cursor c = cr.query(childrenUri, proj, null, null, null)) {
            if (c != null) {
                while (c.moveToNext()) {
                    if (name.equals(c.getString(1))
                            && DocumentsContract.Document.MIME_TYPE_DIR.equals(c.getString(2))) {
                        return DocumentsContract.buildDocumentUriUsingTree(treeUri, c.getString(0));
                    }
                }
            }
        } catch (Throwable ignored) {
        }
        return null;
    }

    private Uri findOrCreateSafSubdir(ContentResolver cr, Uri treeUri, Uri parentDocUri, String name) {
        Uri existing = findExistingSafSubdir(cr, treeUri, parentDocUri, name);
        if (existing != null) return existing;
        try {
            return DocumentsContract.createDocument(
                    cr, parentDocUri, DocumentsContract.Document.MIME_TYPE_DIR, name);
        } catch (Throwable ignored) {
            return null;
        }
    }

    private static class SafChild {
        final Uri uri;
        final String name;
        final boolean isDir;

        SafChild(Uri uri, String name, boolean isDir) {
            this.uri = uri;
            this.name = name;
            this.isDir = isDir;
        }
    }

    private List<SafChild> listSafChildren(ContentResolver cr, Uri treeUri, Uri dirDocUri) {
        List<SafChild> out = new ArrayList<>();
        Uri childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(
                treeUri, DocumentsContract.getDocumentId(dirDocUri));
        String[] proj = new String[]{
                DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                DocumentsContract.Document.COLUMN_MIME_TYPE
        };
        try (Cursor c = cr.query(childrenUri, proj, null, null, null)) {
            if (c != null) {
                while (c.moveToNext()) {
                    String docId = c.getString(0);
                    String name = c.getString(1);
                    if (name == null) continue;
                    boolean isDir = DocumentsContract.Document.MIME_TYPE_DIR.equals(c.getString(2));
                    out.add(new SafChild(
                            DocumentsContract.buildDocumentUriUsingTree(treeUri, docId),
                            name,
                            isDir));
                }
            }
        } catch (Throwable ignored) {
        }
        return out;
    }

    private int syncSafRelativeTree(
            ContentResolver cr,
            Uri treeUri,
            Uri appFolder,
            List<Map<String, Object>> files,
            List<String> keepPaths
    ) {
        Map<String, Uri> dirCache = new HashMap<>();
        dirCache.put("", appFolder);
        Map<String, List<Map<String, Object>>> byDir = new LinkedHashMap<>();
        for (Map<String, Object> item : files) {
            String sub = item.get("subDir") instanceof String
                    ? trimSlashes((String) item.get("subDir"))
                    : "";
            byDir.computeIfAbsent(sub, k -> new ArrayList<>()).add(item);
        }

        int written = 0;
        for (Map.Entry<String, List<Map<String, Object>>> entry : byDir.entrySet()) {
            String sub = entry.getKey();
            Uri targetDir = dirCache.get(sub);
            if (targetDir == null) {
                Uri cur = appFolder;
                StringBuilder acc = new StringBuilder();
                for (String seg : sub.split("/")) {
                    if (seg.isEmpty()) continue;
                    if (acc.length() > 0) acc.append('/');
                    acc.append(seg);
                    String accKey = acc.toString();
                    Uri cached = dirCache.get(accKey);
                    if (cached == null) {
                        cached = findOrCreateSafSubdir(cr, treeUri, cur, seg);
                        if (cached == null) {
                            throw new IllegalStateException("Failed to create SAF subdir " + accKey);
                        }
                        dirCache.put(accKey, cached);
                    }
                    cur = cached;
                }
                targetDir = cur;
                dirCache.put(sub, targetDir);
            }

            Map<String, Uri> existingByName = new HashMap<>();
            for (SafChild child : listSafChildren(cr, treeUri, targetDir)) {
                if (!child.isDir) {
                    existingByName.put(child.name, child.uri);
                }
            }

            for (Map<String, Object> item : entry.getValue()) {
                Object fnObj = item.get("fileName");
                if (!(fnObj instanceof String)) continue;
                String fileName = (String) fnObj;
                String mime = item.get("mimeType") instanceof String
                        ? (String) item.get("mimeType")
                        : "text/markdown";
                String content = item.get("content") instanceof String
                        ? (String) item.get("content")
                        : "";
                byte[] bytes = content.getBytes(StandardCharsets.UTF_8);
                if (writeSafBytes(cr, treeUri, targetDir, fileName, mime, bytes, existingByName.get(fileName))) {
                    written++;
                }
            }
        }

        if (keepPaths != null) {
            pruneSafSubtree(cr, treeUri, appFolder, "", new HashSet<>(keepPaths));
        }
        return written;
    }

    private void pruneSafSubtree(
            ContentResolver cr,
            Uri treeUri,
            Uri dirUri,
            String relPrefix,
            Set<String> keepSet
    ) {
        List<SafChild> children = listSafChildren(cr, treeUri, dirUri);
        for (SafChild child : children) {
            String rel = relPrefix.isEmpty() ? child.name : (relPrefix + "/" + child.name);
            if (child.isDir) {
                String dirPrefix = rel + "/";
                boolean dirHasKeep = false;
                for (String k : keepSet) {
                    if (k.startsWith(dirPrefix)) {
                        dirHasKeep = true;
                        break;
                    }
                }
                if (!dirHasKeep) {
                    try {
                        DocumentsContract.deleteDocument(cr, child.uri);
                    } catch (Throwable ignored) {
                    }
                } else {
                    pruneSafSubtree(cr, treeUri, child.uri, rel, keepSet);
                }
            } else if (!keepSet.contains(rel)) {
                try {
                    DocumentsContract.deleteDocument(cr, child.uri);
                } catch (Throwable ignored) {
                }
            }
        }
    }

    private Uri findSafFile(ContentResolver cr, Uri treeUri, Uri parentDocUri, String name) {
        Uri childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(
                treeUri, DocumentsContract.getDocumentId(parentDocUri));
        String[] proj = new String[]{
                DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                DocumentsContract.Document.COLUMN_DISPLAY_NAME
        };
        try (Cursor c = cr.query(childrenUri, proj, null, null, null)) {
            if (c != null) {
                while (c.moveToNext()) {
                    if (name.equals(c.getString(1))) {
                        return DocumentsContract.buildDocumentUriUsingTree(treeUri, c.getString(0));
                    }
                }
            }
        } catch (Throwable ignored) {
        }
        return null;
    }

    private boolean writeSafBytes(
            ContentResolver cr,
            Uri treeUri,
            Uri parentDocUri,
            String name,
            String mime,
            byte[] bytes,
            Uri knownTarget
    ) {
        Uri targetUri = knownTarget != null ? knownTarget : findSafFile(cr, treeUri, parentDocUri, name);
        if (targetUri == null) {
            try {
                targetUri = DocumentsContract.createDocument(cr, parentDocUri, mime, name);
            } catch (Throwable ignored) {
                targetUri = null;
            }
        }
        if (targetUri == null) return false;

        try (OutputStream out = cr.openOutputStream(targetUri, "wt")) {
            if (out != null) {
                out.write(bytes);
                return true;
            }
        } catch (Throwable ignored) {
        }

        try {
            DocumentsContract.deleteDocument(cr, targetUri);
        } catch (Throwable ignored) {
        }
        try {
            Uri recreated = DocumentsContract.createDocument(cr, parentDocUri, mime, name);
            if (recreated != null) {
                try (OutputStream out = cr.openOutputStream(recreated, "w")) {
                    if (out != null) {
                        out.write(bytes);
                        return true;
                    }
                }
            }
        } catch (Throwable ignored) {
        }
        return false;
    }

    private boolean writeSafFileStream(
            ContentResolver cr,
            Uri treeUri,
            Uri parentDocUri,
            String name,
            String mime,
            File srcFile
    ) {
        Uri targetUri = findSafFile(cr, treeUri, parentDocUri, name);
        if (targetUri == null) {
            try {
                targetUri = DocumentsContract.createDocument(cr, parentDocUri, mime, name);
            } catch (Throwable ignored) {
                targetUri = null;
            }
        }
        if (targetUri == null) return false;

        try (OutputStream out = cr.openOutputStream(targetUri, "wt");
             InputStream in = new FileInputStream(srcFile)) {
            if (out != null) {
                copyStream(in, out);
                return true;
            }
        } catch (Throwable ignored) {
        }

        try {
            DocumentsContract.deleteDocument(cr, targetUri);
        } catch (Throwable ignored) {
        }
        try {
            Uri recreated = DocumentsContract.createDocument(cr, parentDocUri, mime, name);
            if (recreated != null) {
                try (OutputStream out = cr.openOutputStream(recreated, "w");
                     InputStream in = new FileInputStream(srcFile)) {
                    if (out != null) {
                        copyStream(in, out);
                        return true;
                    }
                }
            }
        } catch (Throwable ignored) {
        }
        return false;
    }
}
