
package me.hauvo.thumbnail;

import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.Callback;
import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.WritableMap;
import android.media.ThumbnailUtils;
import android.net.Uri;
import android.provider.MediaStore;
import android.provider.MediaStore.Video.Thumbnails;
import android.graphics.Bitmap;
import android.os.Environment;
import android.util.Log;
import android.util.Base64;
import android.media.MediaMetadataRetriever;
import android.graphics.Matrix;

import java.util.UUID;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.FileNotFoundException;
import java.io.InputStream;
import java.io.OutputStream;
import java.io.IOException;


public class RNThumbnailModule extends ReactContextBaseJavaModule {

  private final ReactApplicationContext reactContext;

  public RNThumbnailModule(ReactApplicationContext reactContext) {
    super(reactContext);
    this.reactContext = reactContext;
  }

  @Override
  public String getName() {
    return "RNThumbnail";
  }

  @ReactMethod
  public void get(String filePath, Promise promise) {
    this.getSecondAndType(filePath, 1.0f, "raw", promise);
  }

  @ReactMethod
  public void getSecond(String filePath, float seconds, Promise promise) {
    this.getSecondAndType(filePath, seconds, "raw", promise);
  }

  @ReactMethod
  public void getSecondAndType(String filePath, float seconds, String type, Promise promise) {
    filePath = filePath.replace("file://","");
    long timeUs = (long) seconds * 1000000;
    MediaMetadataRetriever retriever = new MediaMetadataRetriever();
    retriever.setDataSource(filePath);
    Bitmap image = retriever.getFrameAtTime(timeUs, MediaMetadataRetriever.OPTION_CLOSEST_SYNC);

    String fullPath = this.getReactApplicationContext().getFilesDir().getAbsolutePath() + "/thumb";

    try {
      File dir = new File(fullPath);
      if (!dir.exists()) {
        dir.mkdirs();
      }

      OutputStream fOut = null;
      // String fileName = "thumb-" + UUID.randomUUID().toString() + ".jpeg";
      String fileName = "thumb-" + UUID.randomUUID().toString() + ".jpeg";
      File file = new File(fullPath, fileName);
      file.createNewFile();
      fOut = new FileOutputStream(file);

      // 100 means no compression, the lower you go, the stronger the compression
      image.compress(Bitmap.CompressFormat.JPEG, 100, fOut);
      fOut.flush();
      fOut.close();

      // MediaStore.Images.Media.insertImage(reactContext.getContentResolver(), file.getAbsolutePath(), file.getName(), file.getName());

      WritableMap map = Arguments.createMap();

      map.putDouble("width", image.getWidth());
      map.putDouble("height", image.getHeight());
      if (type.equals("raw")) {
        map.putString("path", "file://" + fullPath + '/' + fileName);
      } else if (type.equals("base64")) {
        try {
          InputStream inputStream = getInputStream("file://" + fullPath + '/' + fileName);
          byte[] inputData = getInputStreamBytes(inputStream);
          String base64Content = Base64.encodeToString(inputData, Base64.NO_WRAP);
          map.putString("base64", base64Content);
        } catch (Exception ex) {
          ex.printStackTrace();
        }
        file.delete();
      }

      promise.resolve(map);

    } catch (Exception e) {
      Log.e("E_RNThumnail_ERROR", e.getMessage());
      promise.reject("E_RNThumnail_ERROR", e);
    }
  }

  private static byte[] getInputStreamBytes(InputStream inputStream) throws IOException {
    byte[] bytesResult;
    ByteArrayOutputStream byteBuffer = new ByteArrayOutputStream();
    int bufferSize = 1024;
    byte[] buffer = new byte[bufferSize];
    try {
      int len;
      while ((len = inputStream.read(buffer)) != -1) {
        byteBuffer.write(buffer, 0, len);
      }
      bytesResult = byteBuffer.toByteArray();
    } finally {
      try {
        byteBuffer.close();
      } catch (IOException ignored) {
      }
    }
    return bytesResult;
  }

  private Uri getFileUri(String filepath, boolean isDirectoryAllowed) throws IOException {
    Uri uri = Uri.parse(filepath);
    if (uri.getScheme() == null) {
      // No prefix, assuming that provided path is absolute path to file
      File file = new File(filepath);
      if (!isDirectoryAllowed && file.isDirectory()) {
        throw new IOException("EISDIR: illegal operation on a directory, read '" + filepath + "'");
      }
      uri = Uri.parse("file://" + filepath);
    }
    return uri;
  }

  private InputStream getInputStream(String filepath) throws IOException {
    Uri uri = getFileUri(filepath, false);
    InputStream stream;
    try {
      stream = reactContext.getContentResolver().openInputStream(uri);
    } catch (FileNotFoundException ex) {
      throw new IOException("ENOENT: " + ex.getMessage() + ", open '" + filepath + "'");
    }
    if (stream == null) {
      throw new IOException("ENOENT: could not open an input stream for '" + filepath + "'");
    }
    return stream;
  }
}
