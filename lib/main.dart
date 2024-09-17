import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tsa_rfc3161/tsa_rfc3161.dart';
import 'package:hive/hive.dart';

String boxFilenames = "filenames_v2";
String boxTSQ = "tsq_v2";
String boxTSR = "tsr_v2";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && !Hive.isBoxOpen(boxFilenames)) {
    Hive.init((await getApplicationDocumentsDirectory()).path);
  }

  await Hive.openBox(boxFilenames);

  Hive.registerAdapter(TSARequestAdapter());
  await Hive.openBox<TSARequest>(boxTSQ);

  Hive.registerAdapter(ListTSAResponseAdapter());
  await Hive.openBox<List<TSAResponse>>(boxTSR);

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

  late Box hiveFilenames;
  late Box hiveTSQ;
  late Box hiveTSR;
  String _errorMessage = "";

  @override
  initState() {
    super.initState();
    hiveFilenames = Hive.box(boxFilenames);
    hiveTSQ = Hive.box<TSARequest>(boxTSQ);
    hiveTSR = Hive.box<List<TSAResponse>>(boxTSR);
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
              String filename = hiveFilenames.getAt(index);

              TSARequest tsq = hiveTSQ.get(filename);
              print(tsq.toJSON());

              return Card(child: Text(filename));
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
      TSAResponse tsr =
          await tsq.run(hostname: "http://timestamp.digicert.com");

      List<TSAResponse> list = [tsr];

      //
      // everything is good, let's add
      //
      hiveFilenames.add(result.files.single.path!);
      hiveTSQ.put(result.files.single.path!, tsq);
      hiveTSR.put(result.files.single.path!, list);
      //
    } on Exception catch (e) {
      _errorMessage = "exception : ${e.toString()}";
      SnackBar snackBar = SnackBar(
        content: Text(_errorMessage),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(snackBar);

      return;
    }

    setState(() {});
  }
}

class TSARequestAdapter extends TypeAdapter<TSARequest> {
  @override
  final typeId = 0;

  @override
  TSARequest read(BinaryReader reader) {
    var x = reader.read();
    var y = Map<String, dynamic>.from(
        x); // convert map<dynamic, dynamic> to map<string, dynamic>
    return TSARequest.fromJSON(y);
  }

  @override
  void write(BinaryWriter writer, TSARequest obj) {
    writer.write(obj.toJSON());
  }
}

class ListTSAResponseAdapter extends TypeAdapter<List<TSAResponse>> {
  @override
  final typeId = 1;

  @override
  List<TSAResponse> read(BinaryReader reader) {
    List<TSAResponse> result = [];

    List<dynamic> list = reader.read();
    for (var i = 0; i < list.length; i++) {
      result.add(TSAResponse.fromJSON(list[i]));
    }
    return result;
  }

  @override
  void write(BinaryWriter writer, List<TSAResponse> obj) {
    List<Map<String, dynamic>> list = [];
    for (var i = 0; i < obj.length; i++) {
      list.add(obj[i].toJSON());
    }
    writer.write(list);
  }
}
