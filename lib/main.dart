import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';

List<CameraDescription> cameras;

Future<Null> main() async {
  cameras = await availableCameras();
  runApp(new MaterialApp(
    title: 'FoodyV',
    home: new FirstScreen(),
  ));
}

class FirstScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new CameraApp();
  }
}

class CameraApp extends StatefulWidget {
  @override
  _CameraAppState createState() => new _CameraAppState();
}

class _CameraAppState extends State<CameraApp> {
  CameraController controller;
  String _filePath;

  void _showCameraException(CameraException e) {
    print("${e.code}, ${e.description}");
  }

  void takePicture() async {
    if (!controller.value.isInitialized) {
      print('Error: select a camera first.');
      return;
    }
    final Directory extDir = await getApplicationDocumentsDirectory();
    final String dirPath = '${extDir.path}/Pictures/flutter_test';
    await new Directory(dirPath).create(recursive: true);
    final String filePath = '$dirPath/tmp.jpg';

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
          title: new Text('Foody Vision'),
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
