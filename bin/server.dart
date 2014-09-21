import 'dart:io';
import 'package:mime/mime.dart' as mime;
import 'package:path/path.dart' as path;

String webroot; // Webroot
int requestNumber = 1; // Which folder to read static data from; to reduce impact of disk cache.

main() {
  webroot = path.join(Directory.current.path, 'web');
  HttpServer.bind(InternetAddress.ANY_IP_V4, 8080)
    .then((HttpServer server) {
      server.listen(handleRequest);
    })
    .catchError((e) => print(e.toString()));
}

handleRequest(HttpRequest request) {
  
  // Figure out which file we're serving, using ascending folders to ensure we don't hit disk cache immediately.
  // Although real-world apps will likely benefit from disk caches; they will also have significantly more
  // files than 3!
  var filename = path.join(path.join(webroot, (requestNumber++).toString()), request.uri.pathSegments[1]);
  var file = new File(filename);

  // Roll over when we run out of folders.
  if (requestNumber > 200)
    requestNumber = 1;

  // Use the sync/async handler based on whether the request came to /sync or /async.
  if (request.uri.pathSegments[0] == 'sync') {
    handleRequestSync(request, file);
  } else if (request.uri.pathSegments[0] == 'async') {
    handleRequestAsync(request, file);
  } else {
    handleNotFound(request, file);
  }
}

handleRequestAsync(HttpRequest request, File file) {
  return file.exists()
    .then((exists) {
      if (!exists)
        return;

      var contentType = mime.lookupMimeType(file.path);
      if (contentType != null)
        request.response.headers.set(HttpHeaders.CONTENT_TYPE, contentType);

      request.response
        .addStream(file.readAsBytes().asStream())
        .whenComplete(() => request.response.close());
    });
}

handleRequestSync(HttpRequest request, File file) {
  if (!file.existsSync())
    return;

  var contentType = mime.lookupMimeType(file.path);
  if (contentType != null)
    request.response.headers.set(HttpHeaders.CONTENT_TYPE, contentType);

  var contents = file.readAsBytesSync();
  request.response.add(contents);
  request.response.close();
}

handleNotFound(HttpRequest request, File file) {
  request.response.statusCode = HttpStatus.NOT_FOUND;
  request.response.headers.contentType = new ContentType('text', 'html');
  request.response.write('<h1>404 File Not Found</h1>');
  request.response.write('<p>${file.path}</p>');
  request.response.close();
}