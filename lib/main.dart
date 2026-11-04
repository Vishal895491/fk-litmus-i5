import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/system_info_service.dart';
import 'package:flutter/gestures.dart';
import 'dart:math';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:camera/camera.dart';
import 'dart:async';


void main() => runApp(const FkLitmusApp());

const navy = Color(0xFF142B45);
const panel = Color(0xFF203D5D);
const cyan = Color(0xFF12B9D5);
const green = Color(0xFF19B978);
const red = Color(0xFFE45D65);
const orange = Color(0xFFFFA32A);
const bg = Color(0xFFF4F4F2);

class FkLitmusApp extends StatelessWidget {
  const FkLitmusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FK-LITMUS Diagnostics',
      theme: ThemeData(
        fontFamily: 'Arial',
        scaffoldBackgroundColor: bg,
        colorScheme: ColorScheme.fromSeed(seedColor: cyan),
      ),
      home: const DiagnosticApp(),
    );
  }
}

class DiagnosticApp extends StatefulWidget {
  const DiagnosticApp({super.key});

  @override
  State<DiagnosticApp> createState() => _DiagnosticAppState();
}

class _DiagnosticAppState extends State<DiagnosticApp> {
  Map<String, dynamic> systemInfo = {};
bool loadingSystemInfo = false;
String hardwareError = '';
final FlutterTts flutterTts = FlutterTts();

String speakerNumber = '';
final TextEditingController speakerController =
    TextEditingController();
bool mouseAdvanceScheduled = false;
bool speakerPlaying = false;
bool speakerPlayed = false;
bool speakerVerified = false;
bool speakerFailed = false;
final List<List<String>> keyboardRows = [
  ['`','1','2','3','4','5','6','7','8','9','0','-','=','Backspace'],
  ['Tab','Q','W','E','R','T','Y','U','I','O','P','[',']','\\'],
  ['Caps','A','S','D','F','G','H','J','K','L',';',"'",'Enter'],
  ['LShift','Z','X','C','V','B','N','M',',','.','/','RShift','Up'],
  ['LCtrl','LAlt','Space','RAlt','RWin','RCtrl','Left','Down','Right'],
];

String hardwareValue(String key) {
  final value = systemInfo[key];

  if (value == null || value.toString().isEmpty) {
    return 'Unavailable';
  }

  return value.toString();
}
  int step = 0;
  String trackingId = '';
  String brand = 'Dell Inc.';
  String model = 'Latitude 5490';
  String serial = 'DEMO-SERIAL';
  bool mousePassed = false;
  bool leftClickDetected = false;
  bool rightClickDetected = false;
  bool keyboardPassed = false;
  Timer? keyboardTimer;
  int keyboardSeconds = 15;
  bool keyboardTimerStarted = false;
  bool keyboardTimeExpired = false;
  bool speakerPassed = false;
  Timer? speakerTimer;
  int speakerSeconds = 15;
  bool speakerTimerStarted = false;
  bool speakerTimeExpired = false;
  bool batteryPassed = true;
  bool cameraPassed = false;
  CameraController? cameraController;
List<CameraDescription> cameras = [];

bool cameraInitialized = false;
bool cameraLoading = false;
String cameraError = '';

XFile? capturedImage;
bool photoAccepted = false;
  bool showSummary = false;
  Future<void> finishCameraTest(bool passed) async {
  cameraPassed = passed;

  await stopCamera();

  if (!mounted) return;

  setState(() {});

  await Future.delayed(const Duration(milliseconds: 700));

  if (mounted && step == 6) {
    next();
  }
}
 
void startKeyboardTimer() {
  if (keyboardTimerStarted) return;

  keyboardTimerStarted = true;
  keyboardSeconds = 15;
  keyboardTimeExpired = false;

  keyboardTimer = Timer.periodic(
    const Duration(seconds: 1),
    (timer) {
      if (!mounted) {
        timer.cancel();
        keyboardTimerStarted = false;
        return;
      }

      if (keyboardSeconds > 1) {
        setState(() {
          keyboardSeconds--;
        });
      } else {
        timer.cancel();
        keyboardTimerStarted = false;

        setState(() {
          keyboardSeconds = 0;
          keyboardTimeExpired = true;
          keyboardPassed = false;
        });

        // Automatically move to the next test after timeout.
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted) return;
          next();
        });
      }
    },
  );
}

  final controller = TextEditingController();
  final Set<String> pressedKeys = {};
  String? getKeyName(KeyEvent event) {
  final key = event.logicalKey;
  final physical = event.physicalKey.debugName ?? '';

  // Left aur right modifier keys ko alag detect karo
  if (physical.contains('ShiftLeft')) return 'LShift';
  if (physical.contains('ShiftRight')) return 'RShift';
  if (physical.contains('ControlLeft')) return 'LCtrl';
  if (physical.contains('ControlRight')) return 'RCtrl';
  if (physical.contains('AltLeft')) return 'LAlt';
  if (physical.contains('AltRight')) return 'RAlt';
  if (physical.contains('MetaLeft')) return 'LWin';

  // Special keys
  if (key == LogicalKeyboardKey.space) return 'Space';
  if (key == LogicalKeyboardKey.enter) return 'Enter';
  if (key == LogicalKeyboardKey.tab) return 'Tab';
  if (key == LogicalKeyboardKey.backspace) return 'Backspace';
  if (key == LogicalKeyboardKey.capsLock) return 'Caps';
  if (key == LogicalKeyboardKey.arrowLeft) return 'Left';
  if (key == LogicalKeyboardKey.arrowRight) return 'Right';
  if (key == LogicalKeyboardKey.arrowUp) return 'Up';
  if (key == LogicalKeyboardKey.arrowDown) return 'Down';

  // Normal letters, numbers and symbols
  final label = key.keyLabel;

  if (label.length == 1) {
    return label.toUpperCase();
  }

  return null;
}

KeyEventResult handleKeyboardEvent(
  FocusNode node,
  KeyEvent event,
) {
  if (event is KeyDownEvent) {
    final name = getKeyName(event);

    if (name != null && !pressedKeys.contains(name)) {
      setState(() {
        pressedKeys.add(name);
      });
    }
  }

  return KeyEventResult.handled;
}

  void next() => setState(() => step++);
  void back() => setState(() => step = step > 0 ? step - 1 : 0);

  Future<void> startDiagnostics() async {
  if (controller.text.trim().isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please enter Tracking ID')),
    );
    return;
  }

  setState(() {
    trackingId = controller.text.trim();
    step = 1;
    loadingSystemInfo = true;
    hardwareError = '';
  });

  try {
    final data = await SystemInfoService.fetch();

    if (!mounted) return;

    setState(() {
      systemInfo = data;
      loadingSystemInfo = false;
    });
  } catch (e) {
    if (!mounted) return;

    setState(() {
      loadingSystemInfo = false;
      hardwareError = e.toString();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Hardware detection error: $e')),
    );
  }
}

 
  

Widget actionButton(
  String text,
  Color color,
  VoidCallback onTap, {
  IconData? icon,
  double width = 190,
}) {
  return SizedBox(
    width: width,
    height: 43,
    child: ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20),
            const SizedBox(width: 7),
          ],
          Text(
            text,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}




  Widget darkPanel(Widget child, {double? height}) {
    return Container(
      width: double.infinity,
      height: height,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(5),
      ),
      child: child,
    );
  }

  Widget heading(String text) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 12),
    color: navy,
    alignment: Alignment.center,
    child: Text(text,
      textAlign: TextAlign.center,
      style: const TextStyle(color: Colors.white, fontSize: 16)),
  );

  Widget infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(children: [
      Expanded(flex: 5, child: Text(label,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
      Expanded(flex: 6, child: Text(value,
        style: const TextStyle(color: Colors.white))),
    ]),
  );
  
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1050),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: buildStep(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildStep() {
    switch (step) {
      case 0: return entryScreen();
      case 1: return deviceScreen();
      case 2: return mouseScreen();
      case 3: return keyboardScreen();
      case 4: return speakerScreen();
      case 5: return batteryScreen();
      case 6: return cameraScreen();
      case 7: return completeScreen();
      case 8: return summaryScreen();
      default: return entryScreen();
    }
  }

  Widget entryScreen() {
  return Center(
    key: const ValueKey(0),
    child: Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 1000),
      padding: const EdgeInsets.fromLTRB(45, 35, 45, 35),
      decoration: BoxDecoration(
        color: navy,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // HEADER
          Row(
            children: [
              const Expanded(
                child: Text(
                  'FK-LITMUS Diagnostics',
                  style: TextStyle(
                    color: cyan,
                    fontSize: 27,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 18,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: green, width: 2),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_box_outlined,
                        color: green, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Internet: Status not checked',
                      style: TextStyle(color: green, fontSize: 15),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 25),

          const Text(
            'Hardware Testing Suite',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 18,
            ),
          ),

          const SizedBox(height: 48),

          const Text(
            'Enter Reverse TID / Order ID / Shipment ID :',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),

          const SizedBox(height: 22),

          // TRACKING ID INPUT
          SizedBox(
            width: 390,
            child: TextField(
              controller: controller,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: 'Enter your tracking ID here...',
                hintStyle: const TextStyle(
                  color: Colors.white60,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 22,
                  horizontal: 15,
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(
                    color: cyan,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(7),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(
                    color: cyan,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
            ),
          ),

          const SizedBox(height: 30),

          // ENTER BUTTON
          actionButton(
            'Enter Tracking ID',
            orange,
            () {
              final trackingId = controller.text.trim();

              if (!trackingId.toUpperCase().startsWith('FMPR')) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Invalid ID! Tracking ID must start with FMPR.',
                    ),
                  ),
                );
                return;
              }

              startDiagnostics();
            },
            icon: Icons.login,
            width: 320,
          ),

          const SizedBox(height: 12),

          // CONNECTION BUTTON
          actionButton(
            'Check Connection',
            cyan,
            () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Connection check requested.'),
                ),
              );
            },
            icon: Icons.wifi,
            width: 200,
          ),

          const SizedBox(height: 32),

          const Text(
            'This diagnostic tool requires an internet connection to upload results',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 17,
            ),
          ),
        ],
      ),
    ),
  );
}
 Widget loadingScreen() {
  return Center(
    key: const ValueKey(9),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'System Diagnostics',
          style: TextStyle(
            color: cyan,
            fontSize: 30,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 35),
        Container(
          width: 340,
          padding: const EdgeInsets.all(10),
          color: navy,
          child: const Text(
            'Gathering system information',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
        const SizedBox(height: 20),
        const CircularProgressIndicator(color: cyan),
      ],
    ),
  );
}

  
Widget deviceScreen() {
  return Column(
    key: const ValueKey(1),
    children: [
      // Top title bar
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 17),
        decoration: BoxDecoration(
          color: const Color(0xFF17182D),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: const Text(
          'FK Litmus v2.2.4-win',
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      const SizedBox(height: 20),

      // Tracking ID panel
      Container(
        width: double.infinity,
        height: 200,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF173C40),
          border: Border.all(color: cyan, width: 2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          'Tracking ID: $trackingId',
          style: const TextStyle(
            color: cyan,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      const SizedBox(height: 13),

      // Hardware details panel
      SizedBox(
        height: 300,
         // yahan height kam/zyada karna
        child: darkPanel(
          loadingSystemInfo
              ? const Center(
                  child: CircularProgressIndicator(color: cyan),
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          // if (hardwareError.isNotEmpty)
                          //   Text(
                          //     hardwareError,
                          //     style: const TextStyle(color: red),
                          //   ),
                          infoRow('Laptop Brand:', hardwareValue('brand')),
                          infoRow('Laptop Model:', hardwareValue('model')),
                          infoRow('Serial Number:', hardwareValue('serial')),
                          infoRow('Processor Label:', 'Intel(R) Core(TM) i5 Processor'),
                          infoRow('Processor Type:', 'Intel'),
                          infoRow('Processor Label:', 'Intel Core i5'),
                        ],
                      ),
                    ),

                    const SizedBox(width: 30),

                    Expanded(
                      child:Column(
                        children: [
                          infoRow('RAM (GB):', '4GB'),
                          infoRow('Storage (GB):', '256GB'),
                          infoRow('WiFi Available:', 'Yes'),
                          infoRow('Bluetooth Available:', 'Yes'),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),

      const SizedBox(height: 14),

      // Bottom action buttons
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          actionButton('✕', red, back, width: 65),
          const SizedBox(width: 15),
          actionButton('✓', green, next, width: 65),
        ],
      ),
    ],
  );
}



Widget mouseScreen() {
  void detectMouseClick(PointerEvent event) {
  if (event is! PointerDownEvent) return;

  setState(() {
    if ((event.buttons & kPrimaryMouseButton) != 0) {
      leftClickDetected = true;
    }

    if ((event.buttons & kSecondaryMouseButton) != 0) {
      rightClickDetected = true;
    }

    if (leftClickDetected && rightClickDetected) {
      mousePassed = true;
    }
  });

  if (leftClickDetected &&
      rightClickDetected &&
      !mouseAdvanceScheduled) {
    mouseAdvanceScheduled = true;

    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      next();
    });
  }
}

  return Column(
    key: const ValueKey(2),
    children: [
      // TOP INSTRUCTION
      Container(
        width: double.infinity,
        height: 30,
        alignment: Alignment.center,
        color: navy,
        child: const Text(
          'Click the buttons with the correct mouse button:',
          style: TextStyle(color: Colors.white, fontSize: 14),
        ),
      ),

      const SizedBox(height: 18),

      // BOTH CLICK BUTTONS - LISTENER
      Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: detectMouseClick,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: actionButton(
                'Left Click',
                leftClickDetected ? green : panel,
                () {},
                width: 450,
              ),
            ),

            const SizedBox(width: 35),

            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: actionButton(
                'Right Click',
                rightClickDetected ? green : panel,
                () {},
                width: 450,
              ),
            ),
          ],
        ),
      ),

      const SizedBox(height: 25),

      // SEPARATOR
      Container(
        width: double.infinity,
        height: 16,
        color: navy,
      ),

      // WHITE TESTING AREA - LISTENER
      Expanded(
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: detectMouseClick,
          child: Container(
            width: double.infinity,
            color: Colors.white,
          ),
        ),
      ),

      // BOTTOM INSTRUCTION
      Container(
        width: double.infinity,
        height: 22,
        alignment: Alignment.center,
        color: navy,
        child: const Text(
          "If mouse/trackpad doesn't work, press 'X' key or click the button below:",
          style: TextStyle(color: Colors.white, fontSize: 11),
          textAlign: TextAlign.center,
        ),
      ),

      const SizedBox(height: 15),

      // BOTTOM BUTTONS
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          actionButton(
            '← Back',
            cyan,
            back,
            width: 145,
          ),
          if (mousePassed)
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text(
              '✓ TEST PASSED',
              style: TextStyle(
                color: Colors.green,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 18),

          actionButton(
            'X Mark as Fail',
            red,
            () {
              setState(() {
                mousePassed = false;
              });
              next();
            },
            width: 150,
          ),
        ],
      ),
    ],
  );
}

  Widget keyboardScreen() {
    startKeyboardTimer();

    return Focus(
      autofocus: true,
      onKeyEvent: handleKeyboardEvent,
      child: Column(
        key: const ValueKey(3),
        children: [
          // TOP KEYBOARD AREA
          Expanded(
            flex: 4,
            child: Container(
              width: double.infinity,
              color: navy,
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 5,
              ),
              child: Column(
                children: keyboardRows.map((row) {
                  return Expanded(
                    child: Row(
                      children: row.map((key) {
                        return Expanded(
                          flex: key == 'Space'
                              ? 5
                              : key.length > 2
                                  ? 2
                                  : 1,
                          child: Padding(
                            padding: const EdgeInsets.all(3),
                            child: ElevatedButton(
                              onPressed: () {},
                              style: ElevatedButton.styleFrom(
                                backgroundColor: pressedKeys.contains(key) ? green : const Color(0xFF245477),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  key,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // WHITE SEPARATOR
          Container(
            height: 8,
            width: double.infinity,
            color: Colors.white,
          ),

          // BOTTOM COUNTDOWN PANEL
          Expanded(
            flex: 5,
            child: Container(
              width: double.infinity,
              color: panel,
              alignment: Alignment.center,
              child: Text(
                'Time remaining: ${keyboardSeconds}s',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

Future<void> playSpeakerTest() async {
  final number = Random().nextInt(9000) + 1000;

  setState(() {
    speakerNumber = number.toString();
    speakerController.clear();
    speakerPlaying = true;
    speakerPlayed = false;
    speakerVerified = false;
    speakerFailed = false;
  });

  try {
    await flutterTts.setLanguage('en-US');
    await flutterTts.setSpeechRate(0.4);
    await flutterTts.setVolume(1.0);
    await flutterTts.setPitch(1.0);

    await flutterTts.awaitSpeakCompletion(true);

    await flutterTts.speak(
      'Listen carefully. Your verification number is $number',
    );

    if (mounted) {
      setState(() {
        speakerPlaying = false;
        speakerPlayed = true;
      });
    }
  } catch (e) {
    if (mounted) {
      setState(() {
        speakerPlaying = false;
        speakerFailed = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Speaker error: $e')),
      );
    }
  }
}
Future<void> verifySpeakerNumber() async {
  if (!speakerPlayed) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please play the speaker test first'),
      ),
    );
    return;
  }

  final enteredCode = speakerController.text.trim();
  final isCorrect = enteredCode == speakerNumber;

  setState(() {
    speakerVerified = isCorrect;
    speakerFailed = !isCorrect;
    speakerPassed = isCorrect;
  });

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(
          isCorrect ? 'Correct Code' : 'Incorrect Code',
        ),
        content: Text(
          isCorrect
              ? 'Entered code is correct.'
              : 'Entered code is incorrect.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
            },
            child: const Text('OK'),
          ),
        ],
      );
    },
  );

  if (!mounted) return;

  next();
}
Future<void> initializeCamera() async {
  if (cameraLoading || cameraInitialized) return;

  setState(() {
    cameraLoading = true;
    cameraError = '';
  });

  try {
    cameras = await availableCameras();

    if (cameras.isEmpty) {
      throw Exception('No camera detected on this device.');
    }

    final camera = cameras.first;

    final controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await controller.initialize();

    if (!mounted) {
      await controller.dispose();
      return;
    }

    setState(() {
      cameraController = controller;
      cameraInitialized = true;
      cameraLoading = false;
    });
  } catch (e) {
    if (!mounted) return;

    setState(() {
      cameraLoading = false;
      cameraInitialized = false;
      cameraError = e.toString();
    });
  }
}
Future<void> captureCameraImage() async {
  if (cameraController == null ||
      !cameraController!.value.isInitialized ||
      cameraController!.value.isTakingPicture) {
    return;
  }

  try {
    final image = await cameraController!.takePicture();

    if (!mounted) return;

    setState(() {
      capturedImage = image;
      photoAccepted = false;
    });
  } catch (e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Photo capture failed: $e')),
    );
  }
}
  Future<void> stopCamera() async {
  final controller = cameraController;

  cameraController = null;

  if (mounted) {
    setState(() {
      cameraInitialized = false;
      cameraLoading = false;
    });
  }

  if (controller != null) {
    await controller.dispose();
  }
}

Widget speakerScreen() {
  return Column(
    key: const ValueKey(4),
    children: [
      // TOP NAVY HEADER
      Container(
        width: double.infinity,
        height: 145,
        color: navy,
        alignment: Alignment.center,
        child: const Text(
          'Speaker Test: Click to play sound, then enter result.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      // MAIN WHITE AREA
      Expanded(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                // PLAY BUTTON
                Positioned(
                  top: constraints.maxHeight * 0.20,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: actionButton(
                      '',
                      cyan,
                      speakerPlaying || speakerTimeExpired
                          ? () {}
                          : playSpeakerTest,
                      icon: Icons.play_arrow,
                      width: 110,
                    ),
                  ),
                ),

                // AUDIO INPUT + CONFIRM BUTTON
                Positioned(
                  left: 15,
                  right: 15,
                  top: constraints.maxHeight * 0.63,
                  child: Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 45,
                          child: TextField(
                            controller: speakerController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Enter the audio you heard',
                              hintStyle: const TextStyle(
                                color: Colors.white70,
                              ),
                              filled: true,
                              fillColor: navy,
                              contentPadding:
                                  const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 15),

                     actionButton(
                      'Confirm',
                      green,
                      () {
                        verifySpeakerNumber();
                      },
                      width: 100,
                    ),
                    ],
                  ),
                ),

                // BACK BUTTON
                Positioned(
                  bottom: 30,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: actionButton(
                      '← Back',
                      cyan,
                      () {
                        speakerTimer?.cancel();
                        speakerTimerStarted = false;
                        speakerSeconds = 15;
                        speakerTimeExpired = false;
                        back();
                      },
                      width: 140,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ],
  );
}

 
  Widget batteryScreen() {
    return Column(
      key: const ValueKey(5),
      children: [
        // TOP TITLE PANEL
        Expanded(
          flex: 4,
          child: darkPanel(
            const Center(
              child: Text(
                'Battery Health Information',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 8),

        // BATTERY DETAILS PANEL
        Expanded(
          flex: 4,
          child: darkPanel(
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Battery Percentage: ${hardwareValue('batteryPercentage')}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Design Capacity: ${hardwareValue('designCapacity')} mWh',
                    style: const TextStyle(color: Colors.white),
                  ),
                  Text(
                    'Full Charge Capacity: ${hardwareValue('fullChargeCapacity')} mWh',
                    style: const TextStyle(color: Colors.white),
                  ),
                  Text(
                    'Health: ${hardwareValue('batteryHealth')}%',
                    style: const TextStyle(color: Colors.white),
                  ),
                  const Text(
                    'Cycle Count: Unavailable',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 10),

        // RED AND GREEN BUTTONS
        SizedBox(
          height: 43,
          child: Row(
            children: [
              Expanded(
                child: actionButton(
                  '✕',
                  red,
                  () {
                    batteryPassed = false;
                    next();
                  },
                  width: double.infinity,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: actionButton(
                  '✓',
                  green,
                  () {
                    batteryPassed = true;
                    next();
                  },
                  width: double.infinity,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // BACK BUTTON
        actionButton(
          '← Back',
          cyan,
          back,
          width: 110,
        ),
      ],
    );
  }
  
  
Widget cameraScreen() {
  return Column(
    key: const ValueKey(6),
    children: [
      Container(
        width: double.infinity,
        height: 30,
        alignment: Alignment.center,
        color: navy,
        child: const Text(
          'Camera Test: Check if you see yourself below.',
          style: TextStyle(color: Colors.white, fontSize: 12),
        ),
      ),

      const SizedBox(height: 8),

      Expanded(
        flex: 7,
        child: Center(
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              color: Colors.black,
              child: capturedImage != null
                  ? FutureBuilder(
                      future: capturedImage!.readAsBytes(),
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          return Image.memory(
                            snapshot.data!,
                            fit: BoxFit.contain,
                          );
                        }
                        return const Center(
                          child: CircularProgressIndicator(color: cyan),
                        );
                      },
                    )
                  : cameraInitialized && cameraController != null
                      ? CameraPreview(cameraController!)
                      : Center(
                          child: cameraLoading
                              ? const CircularProgressIndicator(color: cyan)
                              : Text(
                                  cameraError.isNotEmpty
                                      ? cameraError
                                      : 'Camera is not started',
                                  style: const TextStyle(color: Colors.white),
                                  textAlign: TextAlign.center,
                                ),
                        ),
            ),
          ),
        ),
      ),

      const SizedBox(height: 12),

      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        child: SizedBox(
          width: double.infinity,
          height: 40,
          child: ElevatedButton(
            onPressed: capturedImage == null && !cameraLoading
                ? () async {
                    if (!cameraInitialized) {
                      await initializeCamera();

                      if (!mounted) return;

                      if (!cameraInitialized) {
                        await finishCameraTest(false);
                        return;
                      }
                    }

                    await captureCameraImage();

                    if (!mounted) return;

                    if (capturedImage != null) {
                      await finishCameraTest(true);
                    } else if (cameraError.isNotEmpty) {
                      await finishCameraTest(false);
                    }
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: cyan,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            child: const Text('Capture', style: TextStyle(fontSize: 16)),
          ),
        ),
      ),

      const SizedBox(height: 24),

      actionButton(
        '← Back',
        cyan,
        () async {
          await stopCamera();
          back();
        },
        width: 110,
      ),

      const SizedBox(height: 12),
    ],
  );
}

  Widget completeScreen() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Column(
            key: const ValueKey(7),
            children: [
              const SizedBox(height: 25),

              // TOP HEADING
              const Text(
                'Diagnostics Complete!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: cyan,
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 22),

              // SUCCESS MESSAGE
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                color: const Color(0xFF176B52),
                child: const Text(
                  '✓ Diagnostics completed successfully!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ),

              // RESPONSIVE EMPTY SPACE
              const Spacer(flex: 3),

              // SUMMARY TEXT
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 3,
                ),
                color: navy,
                child: const Text(
                  'View a summary of your diagnostics report:',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // VIEW SUMMARY BUTTON
              actionButton(
                '🔎 View Summary',
                green,
                next,
                width: 250,
              ),

              const Spacer(flex: 1),

              // CLOSE APPLICATION BUTTON
              actionButton(
                '▣ Close Application',
                red,
                () {
                  setState(() => step = 0);
                },
                width: 200,
              ),

              const SizedBox(height: 25),
            ],
          ),
        );
      },
    );
  }




 Widget summaryScreen() {
  return Column(
    key: const ValueKey(8),
    children: [
      heading('Diagnostics Summary'),
      const SizedBox(height: 12),

      Expanded(
        child: darkPanel(
          SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tracking ID
                summaryText('tracking_id: $trackingId', bold: true),
                const SizedBox(height: 18),

                // Test Results
                summaryText(
                  'camera_test: ${cameraPassed ? "Pass" : "Fail"}',
                ),
                const SizedBox(height: 12),

                summaryText(
                  'trackpad_test: ${mousePassed ? "Pass" : "Fail"}',
                ),
                const SizedBox(height: 12),

                summaryText(
                  'keyboard_test: ${keyboardPassed ? "Pass" : "Fail"}',
                ),
                const SizedBox(height: 8),

                const SizedBox(height: 12),

                summaryText(
                  'speaker_test: ${speakerPassed ? "Pass" : "Fail"}',
                ),
                const SizedBox(height: 12),

                summaryText(
                  'battery_test:',
                  bold: true,
                ),

                summaryText(
                  '  Design_Capacity: ${hardwareValue('designCapacity')} mWh\n'
                  '  Health: ${hardwareValue('batteryHealth')}%\n'
                  '  Battery_Percentage: ${hardwareValue('batteryPercentage')}%\n'
                  '  Cycle_Count: Unavailable\n'
                  '  Full_Charge_Capacity: ${hardwareValue('fullChargeCapacity')} mWh',
                ),

                const SizedBox(height: 18),

                // System Information
                summaryText('system_info', bold: true),

                summaryText(
                  '  Laptop_Brand: ${hardwareValue('brand')}\n'
                  '  Laptop_Model: ${hardwareValue('model')}\n'
                  '  Processor : Intel(R) Core(TM) i5-12050U CPU @ 2.50GHz\n'
                  '  RAM_GB: 4GB \n'
                  '  Primary_Disk_Total_GB: 256GB \n'
                  '  Serial_Number: ${hardwareValue('serial')}',
                ),
              ],
            ),
          ),
        ),
      ),

      const SizedBox(height: 12),

      actionButton(
        'Close',
        cyan,
        () {
          setState(() {
            step = 0;
          });
        },
      ),
    ],
  );
}

// Summary text helper
Widget summaryText(String text, {bool bold = false}) {
  return Text(
    text,
    style: TextStyle(
      color: Colors.white,
      fontSize: 15,
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
    ),
  );
}
    @override
    void dispose() {
      cameraController?.dispose();
      speakerController.dispose();
      keyboardTimer?.cancel();  
      super.dispose();
}
}
