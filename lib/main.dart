import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MyHomePage(),
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.deepPurple,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Colors.deepPurpleAccent,
            textStyle: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.deepPurpleAccent,
          centerTitle: true,
          titleTextStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        cardColor: Color(0xFF2C2C2E),
        scaffoldBackgroundColor: Color(0xFF1C1C1E),
        dividerColor: Colors.grey.shade700,
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  static const MethodChannel installChannel = MethodChannel('com.example.virtual_tray_app/install');
  static const MethodChannel infoChannel = MethodChannel('com.example.virtual_tray_app/info');
  static const MethodChannel launchChannel = MethodChannel('com.example.virtual_tray_app/launch');

  List<ProjectFolder> folders = [];
  List<bool> folderOpen = [];

  @override
  void initState() {
    super.initState();
    loadFolders();
  }

  Future<void> loadFolders() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'folders.json'));
    if (await file.exists()) {
      final content = await file.readAsString();
      final List data = jsonDecode(content);
      setState(() {
        folders = data.map((e) => ProjectFolder.fromJson(e)).toList();
        folderOpen = List.generate(folders.length, (_) => false);
      });
    }
  }

  Future<void> saveFolders() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'folders.json'));
    await file.writeAsString(jsonEncode(folders.map((e) => e.toJson()).toList()));
  }

  Future<Map<String, String>> getApkInfo(String apkPath) async {
    try {
      final Map info = await infoChannel.invokeMethod('getApkInfo', {'apkPath': apkPath});
      return Map<String, String>.from(info);
    } catch (e) {
      return {};
    }
  }

  Future<void> launchApp(String packageName) async {
    try {
      await launchChannel.invokeMethod('launchApp', {'packageName': packageName});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to launch: ${e.toString()}')),
      );
    }
  }

  void removeClone(int folderIndex, int cloneIndex) {
    setState(() {
      folders[folderIndex].clones.removeAt(cloneIndex);
    });
    saveFolders();
  }

  void addProjectFolder(String name) {
    setState(() {
      folders.add(ProjectFolder(name));
      folderOpen.add(false);
    });
    saveFolders();
  }

  void deleteProjectFolder(int index) async {
    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Delete Folder"),
        content: Text("Are you sure you want to delete this folder and all its APKs?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text("Delete")),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() {
        folders.removeAt(index);
        folderOpen.removeAt(index);
      });
      saveFolders();
    }
  }

  Future<void> addApkToFolder(int folderIndex, String apkPath, String customName) async {
    if (folderIndex >= 0 && folderIndex < folders.length) {
      Map<String, String> metadata = await getApkInfo(apkPath);
      setState(() {
        folders[folderIndex].clones.add(CloneApk(apkPath, customName, metadata));
      });
      await saveFolders();
    }
  }

  void renameClone(int folderIndex, int cloneIndex, String newName) {
    setState(() {
      folders[folderIndex].clones[cloneIndex].customName = newName;
    });
    saveFolders();
  }

  Future<void> pickApk(int folderIndex) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result != null && result.files.single.path != null) {
      String path = result.files.single.path!;
      if (path.toLowerCase().endsWith('.apk')) {
        TextEditingController nameController = TextEditingController();
        bool? confirmed = await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text("Enter custom name"),
              content: TextField(controller: nameController),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: Text("Cancel")),
                TextButton(onPressed: () => Navigator.pop(context, true), child: Text("Add")),
              ],
            );
          },
        );

        if (confirmed == true && nameController.text.isNotEmpty) {
          await addApkToFolder(folderIndex, path, nameController.text);
        }
      }
    }
  }

  Widget apkDetailsWidget(Map<String, String> details) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: details.entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.0),
          child: Text("${entry.key}: ${entry.value}"),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Multi APK Manager")),
      body: ListView.builder(
        itemCount: folders.length,
        itemBuilder: (context, folderIndex) {
          final folder = folders[folderIndex];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 4,
            child: ExpansionTile(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(folder.name, style: Theme.of(context).textTheme.titleLarge)),
                  IconButton(
                    icon: Icon(Icons.delete_forever, color: Colors.redAccent),
                    onPressed: () => deleteProjectFolder(folderIndex),
                  )
                ],
              ),
              initiallyExpanded: folderOpen[folderIndex],
              onExpansionChanged: (expanded) => setState(() => folderOpen[folderIndex] = expanded),
              children: [
                ElevatedButton.icon(
                  onPressed: () => pickApk(folderIndex),
                  icon: Icon(Icons.add),
                  label: Text("Add APK"),
                ),
                const SizedBox(height: 10),
                ...folder.clones.asMap().entries.map((entry) {
                  final cloneIndex = entry.key;
                  final clone = entry.value;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          title: Text(clone.customName),
                          subtitle: Text(clone.apkPath, style: TextStyle(fontSize: 12)),
                          onTap: () => showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: Text("APK Metadata"),
                              content: SingleChildScrollView(child: apkDetailsWidget(clone.metadata)),
                              actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text("Close"))],
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.play_arrow, color: Colors.greenAccent),
                                onPressed: () => launchApp(clone.metadata['Package Name'] ?? ''),
                              ),
                              IconButton(
                                icon: Icon(Icons.edit),
                                onPressed: () async {
                                  TextEditingController renameController = TextEditingController(text: clone.customName);
                                  await showDialog(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: Text("Rename clone"),
                                      content: TextField(controller: renameController),
                                      actions: [
                                        TextButton(
                                          onPressed: () {
                                            renameClone(folderIndex, cloneIndex, renameController.text);
                                            Navigator.pop(context);
                                          },
                                          child: Text("Rename"),
                                        )
                                      ],
                                    ),
                                  );
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.delete, color: Colors.red),
                                onPressed: () => removeClone(folderIndex, cloneIndex),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => installChannel.invokeMethod('installApk', {'apkPath': clone.apkPath}),
                              icon: Icon(Icons.download),
                              label: Text("Install"),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton.icon(
                              onPressed: () => installChannel.invokeMethod('uninstallApp', {'packageName': clone.metadata['Package Name'] ?? ''}),
                              icon: Icon(Icons.delete),
                              label: Text("Uninstall"),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                            ),
                          ],
                        ),
                        Divider(),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.create_new_folder),
        backgroundColor: Colors.deepPurpleAccent,
        onPressed: () {
          TextEditingController folderController = TextEditingController();
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: Text("New Project Folder"),
              content: TextField(controller: folderController),
              actions: [
                TextButton(
                  onPressed: () {
                    addProjectFolder(folderController.text);
                    Navigator.pop(context);
                  },
                  child: Text("Create"),
                )
              ],
            ),
          );
        },
      ),
    );
  }
}

class ProjectFolder {
  String name;
  List<CloneApk> clones;

  ProjectFolder(this.name, [List<CloneApk>? clones]) : clones = clones ?? [];

  Map<String, dynamic> toJson() => {
    'name': name,
    'clones': clones.map((e) => e.toJson()).toList(),
  };

  factory ProjectFolder.fromJson(Map<String, dynamic> json) => ProjectFolder(
    json['name'],
    (json['clones'] as List?)?.map((e) => CloneApk.fromJson(e)).toList() ?? [],
  );
}

class CloneApk {
  String apkPath;
  String customName;
  Map<String, String> metadata;

  CloneApk(this.apkPath, this.customName, [this.metadata = const {}]);

  Map<String, dynamic> toJson() => {
    'apkPath': apkPath,
    'customName': customName,
    'metadata': metadata,
  };

  factory CloneApk.fromJson(Map<String, dynamic> json) => CloneApk(
    json['apkPath'],
    json['customName'],
    Map<String, String>.from(json['metadata'] ?? {}),
  );
}