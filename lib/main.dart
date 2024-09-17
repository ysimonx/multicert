import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tsa_rfc3161/tsa_rfc3161.dart';
import 'package:hive/hive.dart';

String boxFilenames = "filenames_v7";
String boxTSQ = "tsq_v7";
String boxTSR = "tsr_v7";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && !Hive.isBoxOpen(boxFilenames)) {
    Hive.init((await getApplicationDocumentsDirectory()).path);
  }

  await Hive.openBox(boxFilenames);

  Hive.registerAdapter(TSARequestAdapter());
  await Hive.openBox<TSARequest>(boxTSQ);

  Hive.registerAdapter(ListTSAResponseAdapter());
  await Hive.openBox<ListTSAResponse>(boxTSR);

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
    hiveTSR = Hive.box<ListTSAResponse>(boxTSR);
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

              ListTSAResponse? l2 = hiveTSR.get(filename);
              print(l2);

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

      ListTSAResponse listTSAResponse = ListTSAResponse();
      listTSAResponse.items.add(tsr);

      //
      // everything is good, let's add
      //
      hiveFilenames.add(result.files.single.path!);
      hiveTSQ.put(result.files.single.path!, tsq);
      hiveTSR.put(result.files.single.path!, listTSAResponse);

      ListTSAResponse l2 = hiveTSR.get(result.files.single.path!);
      print(l2);

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

class ListTSAResponse {
  List<TSAResponse> items = [];
  ListTSAResponse();

  ListTSAResponse.fromJSON(Map<String, dynamic> json) {
    var list = json["list"];
    for (var i = 0; i < list.length; i++) {
      var l = list[i];

      Map<String, dynamic> item = Map<String, dynamic>.from(l);
      // encode/decode because of "_Map<dynamic, dynamic>" is not a subtype of type "Map<String, dynamic>"
      String s = jsonEncode(item);
      Map<String, dynamic> x = jsonDecode(s);
      items.add(TSAResponse.fromJSON(x));
    }
  }

  Map<String, dynamic> toJSON() {
    Map<String, dynamic> result = {};
    List<dynamic> l = [];
    for (var i = 0; i < items.length; i++) {
      l.add(items[i].toJSON());
    }

    result = {"list": l};
    return result;
  }
}

class TSARequestAdapter extends TypeAdapter<TSARequest> {
  @override
  final typeId = 0;

  @override
  TSARequest read(BinaryReader reader) {
    var x = reader.read();
    // convert map<dynamic, dynamic> to map<string, dynamic>
    var y = Map<String, dynamic>.from(x);
    return TSARequest.fromJSON(y);
  }

  @override
  void write(BinaryWriter writer, TSARequest obj) {
    writer.write(obj.toJSON());
  }
}

class ListTSAResponseAdapter extends TypeAdapter<ListTSAResponse> {
  @override
  final typeId = 1;

  @override
  ListTSAResponse read(BinaryReader reader) {
    var x = reader.read();
    var json = Map<String, dynamic>.from(x);

    ListTSAResponse result = ListTSAResponse.fromJSON(json);
    return result;
  }

  @override
  void write(BinaryWriter writer, ListTSAResponse obj) {
    writer.write(obj.toJSON());
  }
}
