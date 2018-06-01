import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:googleapis/vision/v1.dart' as vision;
import 'httpclient.dart';
import 'package:google_sign_in/google_sign_in.dart'
    show GoogleSignIn;
import 'package:firebase_auth/firebase_auth.dart';

List<CameraDescription> cameras;

Future<Null> main() async {
  cameras = await availableCameras();
  final _googleSignIn = new GoogleSignIn(
    scopes: [
      'email',
      'https://www.googleapis.com/auth/contacts.readonly',
      'https://www.googleapis.com/auth/cloud-vision'
    ],
  );

  final FirebaseAuth _auth = FirebaseAuth.instance;
  var googleUser = await _googleSignIn.signIn();
  var googleAuth = await googleUser.authentication;
  var user = await _auth.signInWithGoogle(
    accessToken: googleAuth.accessToken,
    idToken: googleAuth.idToken,
  );
  print("signed in " + user.displayName);

  var authHeaders = await googleUser.authHeaders;
  var visionApi = vision.VisionApi(new GoogleHttpClient(authHeaders));
  var imp = visionApi.images;
  var request = vision.AnnotateImageRequest()
  ..features = [vision.Feature()..type = "DOCUMENT_TEXT_DETECTION"];
  var imageSource = vision.ImageSource()
  ..gcsImageUri = "gs://bucket-name-123/abbey_road.jpg";
  var image = vision.Image()
  ..source = imageSource;
  request.image = image;
  var annotateRequest = vision.BatchAnnotateImagesRequest()
    ..requests = [request];
  var res = await imp.annotate(annotateRequest);
  res?.responses?.forEach((r) {
    r.textAnnotations.forEach((txt) {
      print(txt.description);
    });
  });
  runApp(new MaterialApp(
    title: 'FoodyV',
    home: new FirstScreen(user?.displayName),
  ));
}

class FirstScreen extends StatelessWidget {
  String _loggedUser;
  FirstScreen(String loggedUser) {
    this._loggedUser = loggedUser;
  }

  @override
  Widget build(BuildContext context) {
    return new CameraApp(_loggedUser);
  }
}

class CameraApp extends StatefulWidget {
  String loggedUser;
  CameraApp(String loggedUser) {
    this.loggedUser = loggedUser;
  }

  @override
  _CameraAppState createState() => new _CameraAppState(loggedUser);
}

class _CameraAppState extends State<CameraApp> {
  CameraController controller;
  String _filePath;
  String loggedUser;

  _CameraAppState(String loggedUser) {
    this.loggedUser = loggedUser;
  }

  void _showCameraException(CameraException e) {
    print("${e.code}, ${e.description}");
  }

  String timestamp() => new DateTime.now().millisecondsSinceEpoch.toString();

  void takePicture() async {
    if (!controller.value.isInitialized) {
      print('Error: select a camera first.');
      return;
    }
    final Directory extDir = await getApplicationDocumentsDirectory();
    final String dirPath = '${extDir.path}/Pictures/flutter_test';
    await new Directory(dirPath).create(recursive: true);
    final String filePath = '$dirPath/${timestamp()}.jpg';

    if (controller.value.isTakingPicture) {
      // A capture is already pending, do nothing.
      return;
    }
    File file = new File(filePath);
    if(file.existsSync()) {
      file.deleteSync();
    }
    try {
      await controller.takePicture(filePath);
    } on CameraException catch (e) {
      _showCameraException(e);
      return;
    }

    _filePath = filePath;
    _navigateToImageScreen();
  }

  Widget _cameraFloatingWidget() {
    return new Align(
        alignment: Alignment.bottomRight,
        child: new FloatingActionButton(
          onPressed: takePicture,
          tooltip: "take a shot",
          child: new Icon(Icons.photo_camera, size: 30.0),
        ));
  }

  void _navigateToImageScreen(){
    Navigator.push(
      context,
      new MaterialPageRoute(builder: (context) => new ImageScreen(filePath: _filePath)),
    );
  }

  @override
  void initState() {
    super.initState();
    controller = new CameraController(cameras[0], ResolutionPreset.high);
    controller.initialize().then((_) {
      if (!mounted) {
        return;
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return new Container();
    }
    return
      new Scaffold(
        appBar: new AppBar(
          actions: <Widget>[new IconButton(icon: new Icon(Icons.photo),
              onPressed: _navigateToImageScreen)],
          title: new Text("$loggedUser"),
        ),
        body: new Center(
          child: new CameraPreview(controller),
        ),
        floatingActionButton: _cameraFloatingWidget(),
      );
  }
}

class ImageScreen extends StatelessWidget {
  final String filePath;
  const ImageScreen({
    Key key,
    this.filePath
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget imageWidget;
    if(filePath == null) {
      imageWidget = new Text('Please take a photo');
    } else {
      imageWidget = new Image.file(new File(filePath));
    }
    return new Scaffold(
      appBar: new AppBar(
        title: new Text("Image Screen"),
      ),
      body: new Center(
        child: imageWidget,
      ),
    );
  }
}
