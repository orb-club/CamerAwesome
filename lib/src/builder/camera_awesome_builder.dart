import 'package:camerawesome/src/orchestrator/models/exif_preferences_data.dart';
import 'package:camerawesome/src/orchestrator/models/media_capture.dart';
import 'package:camerawesome/src/layouts/awesome/awesome_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../orchestrator/sensor_config.dart';
import '../orchestrator/models/capture_modes.dart';
import '../orchestrator/models/flashmodes.dart';
import '../orchestrator/models/sensors.dart';
import '../orchestrator/camera_orchestrator.dart';
import '../orchestrator/states/state_definition.dart';
import '../layouts/awesome/widgets/camera_preview.dart';
import '../layouts/awesome/widgets/pinch_to_zoom.dart';

/// this is the builder for your camera interface
/// Using the state you can do anything you need without having to think about the camera flow
/// On app start we are in [PreparingCameraState]
/// Then depending on the initialCaptureMode you set you will be [PictureCameraState] or [VideoCameraState]
/// Starting a video will push a [VideoRecordingCameraState]
/// Stopping the video will push back the [VideoCameraState]
/// ----
/// If you need to call specific function for a state use the 'when' function.
typedef CameraLayoutBuilder = Widget Function(CameraState cameraModeState);

/// configure the path where we save videos or pictures
typedef FilePathBuilder = Future<String> Function(CaptureModes)?;

/// Callback when a video or picture has been saved and user click on thumbnail
typedef OnMediaTap = Function(MediaCapture mediaState)?;

/// Used to set a permission result callback
typedef OnPermissionsResult = void Function(bool result);

/// This is the entry point of the CameraAwesome plugin
/// You can either
/// - build your custom layout
/// or
/// - use our built in interface
/// with the awesome factory
class CameraAwesomeBuilder extends StatefulWidget {
  // Initial camera config
  final CaptureModes initialCaptureMode;

  final Sensors sensor;

  final CameraFlashes flashMode;

  final double zoom;

  final List<CaptureModes> availableModes;

  final ExifPreferences? exifPreferences;

  final bool enableAudio;

  final FilePathBuilder picturePathBuilder;

  final FilePathBuilder videoPathBuilder;

  final OnMediaTap onMediaTap;

  // Widgets
  final Widget? progressIndicator;

  final CameraLayoutBuilder builder;

  CameraAwesomeBuilder._({
    required this.initialCaptureMode,
    required this.sensor,
    required this.flashMode,
    required this.zoom,
    required this.availableModes,
    required this.exifPreferences,
    required this.enableAudio,
    required this.progressIndicator,
    required this.picturePathBuilder,
    required this.videoPathBuilder,
    required this.onMediaTap,
    required this.builder,
  });

  factory CameraAwesomeBuilder.awesome({
    CaptureModes initialCaptureMode = CaptureModes.PHOTO,
    Sensors sensor = Sensors.BACK,
    CameraFlashes flashMode = CameraFlashes.NONE,
    double zoom = 0.0,
    List<CaptureModes> availableModes = const [
      CaptureModes.PHOTO,
      CaptureModes.VIDEO
    ],
    ExifPreferences? exifPreferences,
    bool enableAudio = true,
    Widget? progressIndicator,
    Future<String> Function(CaptureModes)? picturePathBuilder,
    Future<String> Function(CaptureModes)? videoPathBuilder,
    final Function(MediaCapture)? onMediaTap,
  }) {
    /// TODO refactor this (those two args could be merged)
    if (availableModes.contains(CaptureModes.PHOTO) &&
        picturePathBuilder == null) {
      throw ("You have to provide a path through [picturePathBuilder] to save your picture");
    }

    /// TODO refactor this (those two args could be merged)
    if (availableModes.contains(CaptureModes.VIDEO) &&
        videoPathBuilder == null) {
      throw ("You have to provide a path through [videoPathBuilder] to save your picture");
    }
    return CameraAwesomeBuilder._(
      initialCaptureMode: initialCaptureMode,
      sensor: sensor,
      flashMode: flashMode,
      zoom: zoom,
      availableModes: availableModes,
      exifPreferences: exifPreferences,
      enableAudio: enableAudio,
      progressIndicator: progressIndicator,
      builder: (cameraModeState) => AwesomeCameraLayout(
        state: cameraModeState,
        onMediaTap: onMediaTap,
      ),
      picturePathBuilder: picturePathBuilder,
      videoPathBuilder: videoPathBuilder,
      onMediaTap: onMediaTap,
    );
  }

  CameraAwesomeBuilder.custom({
    CaptureModes initialCaptureMode = CaptureModes.PHOTO,
    Sensors sensor = Sensors.BACK,
    CameraFlashes flashMode = CameraFlashes.NONE,
    double zoom = 0.0,
    List<CaptureModes> availableModes = const [
      CaptureModes.PHOTO,
      CaptureModes.VIDEO
    ],
    ExifPreferences? exifPreferences,
    bool enableAudio = true,
    Widget? progressIndicator,
    required CameraLayoutBuilder builder,
    Future<String> Function(CaptureModes)? picturePathBuilder,
    Future<String> Function(CaptureModes)? videoPathBuilder,
    Function(MediaCapture)? onMediaTap,
  }) : this._(
          initialCaptureMode: initialCaptureMode,
          sensor: sensor,
          flashMode: flashMode,
          zoom: zoom,
          availableModes: availableModes,
          exifPreferences: exifPreferences,
          enableAudio: enableAudio,
          progressIndicator: progressIndicator,
          builder: builder,
          picturePathBuilder: picturePathBuilder,
          videoPathBuilder: videoPathBuilder,
          onMediaTap: onMediaTap,
        );

  @override
  State<StatefulWidget> createState() {
    return _CameraWidgetBuilder();
  }
}

class _CameraWidgetBuilder extends State<CameraAwesomeBuilder>
    with WidgetsBindingObserver {
  late CameraOrchestrator cameraOrchestrator;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    cameraOrchestrator.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CameraAwesomeBuilder oldWidget) {
    // use freezed + copy with
    // cameraOrchestrator.state.setFlash(widget.flashMode);
    // cameraOrchestrator.state.setZoom(widget.zoom);
    // if (widget.initialCaptureMode != oldWidget.initialCaptureMode &&
    //     widget.initialCaptureMode == CaptureModes.PHOTO) {
    //   widget.cameraOrchestrator.startPictureMode(widget.picturePathBuilder);
    // } else if (widget.initialCaptureMode != oldWidget.initialCaptureMode &&
    //     widget.initialCaptureMode == CaptureModes.VIDEO) {
    //   widget.cameraOrchestrator.startVideoMode(widget.videoPathBuilder);
    // }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void didChangeDependencies() {
    // lock by default orientation to portrait up
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.didChangeDependencies();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        cameraOrchestrator.state.start();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        cameraOrchestrator.state.stop();
        break;
    }
    super.didChangeAppLifecycleState(state);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    cameraOrchestrator = CameraOrchestrator.create(
      SensorConfig(
        sensor: widget.sensor,
        flash: widget.flashMode,
        currentZoom: widget.zoom,
      ),
      initialCaptureMode: widget.initialCaptureMode,
      picturePathBuilder: widget.picturePathBuilder,
      videoPathBuilder: widget.videoPathBuilder,
    );

    cameraOrchestrator.state.start();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<CameraState>(
      stream: cameraOrchestrator.state$,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.captureMode == null) {
          return widget.progressIndicator ??
              const Center(
                child: CircularProgressIndicator(),
              );
        }
        return SafeArea(
          child: Container(
            color: Colors.black,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Positioned.fill(
                  child: PinchToZoom(
                    sensorConfig: cameraOrchestrator.sensorConfig,
                    child: CameraPreviewWidget(
                      key: UniqueKey(),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: widget.builder(snapshot.requireData),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
