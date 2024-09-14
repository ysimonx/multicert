import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tsa_rfc3161/tsa_rfc3161.dart';
import 'package:hive/hive.dart';

String boxFilenames = "filenames";
String boxTSQ = "tsq";
String boxTSR = "tsr";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && !Hive.isBoxOpen(boxFilenames)) {
    Hive.init((await getApplicationDocumentsDirectory()).path);
  }

  await Hive.openBox(boxFilenames);
  await Hive.openBox<TSARequest>(boxTSQ);
  Hive.registerAdapter(TSRAequestAdapter());

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<String> filenames = [];
  Map<String, TSAResponse> mapFilenameTSARequest = {};
  Map<String, List<TSAResponse>> mapFilenameTSAResponses = {};

  late Box hiveFilenames;
  late Box hiveTSQ;

  String _errorMessage = "";

  @override
  initState() {
    super.initState();
    hiveFilenames = Hive.box(boxFilenames);
    hiveTSQ = Hive.box<TSARequest>(boxTSQ);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Center(
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Card(
              child: Row(children: [
                IconButton(
                    onPressed: _timestamp,
                    icon: const Icon(Icons.upload_file, size: 100)),
                const Text("Choose file")
              ]),
            ),
          ),
          ListView.builder(
            shrinkWrap: true,
            itemCount: hiveFilenames.length,
            itemBuilder: (BuildContext context, int index) {
              return ListTile(
                title:
                    Text(hiveFilenames.getAt(hiveFilenames.length - index - 1)),
              );
            },
          )
        ],
      ),
    ));
  }

  void _timestamp() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result == null) {
      return;
    }

    int nonceValue =
        DateTime.now().millisecondsSinceEpoch; // Utiliser un entier unique

    try {
      TSARequest tsq = TSARequest.fromFile(
          filepath: result.files.single.path!,
          algorithm: TSAHash.sha256,
          nonce: nonceValue,
          certReq: true);
      //
      // everything is good, let's add
      //
      hiveFilenames.add(result.files.single.path!);
      hiveTSQ.put(result.files.single.path!, tsq);
    } on Exception catch (e) {
      _errorMessage = "exception : ${e.toString()}";
      SnackBar snackBar = SnackBar(
        content: Text(_errorMessage),
      );

      // Find the ScaffoldMessenger in the widget tree
      // and use it to show a SnackBar.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
    }

    setState(() {});
    // _timestampFile(result.files.single.path!);
  }

  Future<void> _timestampFile(filepath) async {
    int nonceValue =
        DateTime.now().millisecondsSinceEpoch; // Utiliser un entier unique

    try {
      TSARequest tsq = TSARequest.fromFile(
          filepath: filepath,
          algorithm: TSAHash.sha256,
          nonce: nonceValue,
          certReq: true);

      TSAResponse? tsr = await TSAResponse(tsq,
              hostnameTimeStampProvider: "http://timestamp.digicert.com")
          .run();

      if (tsr != null) {
        setState(() {});
      } else {
        _errorMessage = "error";
      }
    } on Exception catch (e) {
      _errorMessage = "exception : ${e.toString()}";
    }
    setState(() {});
  }
}

// Can be generated automatically
class TSRAequestAdapter extends TypeAdapter<TSARequest> {
  @override
  final typeId = 0;

  @override
  TSARequest read(BinaryReader reader) {
    return TSARequest.fromUint8List(reader.read());
  }

  @override
  void write(BinaryWriter writer, TSARequest obj) {
    writer.write(obj.asn1sequence.encodedBytes);
  }
}
