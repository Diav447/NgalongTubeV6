import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

void main() => runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: SearchPage()));

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});
  @override
  State<SearchPage> createState() => _S();
}

class _S extends State<SearchPage> {
  final _c = TextEditingController(text: "playlist ngalong malam");
  List vids = [];
  List<String> logs = [];
  bool load = false;
  bool showLog = true;

  void addLog(String s) {
    final time = "${DateTime.now().hour}:${DateTime.now().minute}:${DateTime.now().second}";
    setState(() => logs.insert(0, "[$time] $s"));
    print("[$time] $s");
  }

  Future<String> checkDNS() async {
    try {
      final r = await http.get(Uri.parse("https://1.1.1.1/dns-query?name=google.com"), headers: {"accept": "application/dns-json"}).timeout(const Duration(seconds: 3));
      return r.statusCode == 200? "OK" : "FAIL ${r.statusCode}";
    } catch (e) { return "ERROR $e"; }
  }

  Future<void> search(String q) async {
    setState(() { load = true; vids = []; logs = []; });
    addLog("START search: $q");
    addLog("DNS Private: ${await checkDNS()}");

    final headers = {"User-Agent": "Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36", "Content-Type": "application/json"};
    final apis = ["https://vid.puffyan.us/api/v1/search?q=", "https://invidious.nerdvpn.de/api/v1/search?q=", "https://inv.nadeko.net/api/v1/search?q="];

    // 1. YT WEB
    try {
      addLog("1/5 TRY POST YT WEB");
      var r = await http.post(Uri.parse("https://www.youtube.com/youtubei/v1/search"), headers: headers, body: jsonEncode({"context": {"client": {"clientName": "WEB", "clientVersion": "2.20240101"}}}),).timeout(const Duration(seconds: 12));
      addLog("1/5 RESP Status:${r.statusCode} Length:${r.body.length}");
      if (r.statusCode == 200 && r.body.contains("videoId")) {
        var j = jsonDecode(r.body);
        var contents = j["contents"]?["twoColumnSearchResultsRenderer"]?["primaryContents"]?["sectionListRenderer"]?["contents"];
        if (contents!= null) {
          for (var sec in contents) {
            var items = sec["itemSectionRenderer"]?["contents"];
            if (items == null) continue;
            for (var item in items) {
              var vr = item["videoRenderer"];
              if (vr!= null) vids.add({"title": vr["title"]["runs"][0]["text"], "videoId": vr["videoId"], "author": vr["ownerText"]?["runs"]?[0]?["text"]?? "YT"});
            }
          }
          if (vids.isNotEmpty) { addLog("SUCCESS jalur 1, dapet ${vids.length} video"); setState(() { load = false; }); return; }
        }
      }
      addLog("FAIL jalur 1 - status bukan 200 atau ga ada videoId");
    } catch (e, stack) { addLog("ERROR jalur 1: $e"); }

    // 2. YT ANDROID
    try {
      addLog("2/5 TRY POST YT [ANDROID]");
      var r = await http.post(Uri.parse("https://www.youtube.com/youtubei/v1/search"), headers: headers, body: jsonEncode({"context": {"client": {"clientName": "ANDROID", "clientVersion": "19.02.39"}}}),).timeout(const Duration(seconds: 12));
      addLog("2/5 RESP Status:${r.statusCode} Length:${r.body.length}");
      if (r.statusCode == 200 && r.body.contains("videoId")) {
        var j = jsonDecode(r.body);
        var contents = j["contents"]?["twoColumnSearchResultsRenderer"]?["primaryContents"]?["sectionListRenderer"]?["contents"];
        if (contents!= null) {
          for (var sec in contents) {
            var items = sec["itemSectionRenderer"]?["contents"];
            if (items == null) continue;
            for (var item in items) {
              var vr = item["videoRenderer"];
              if (vr!= null) vids.add({"title": vr["title"]["runs"][0]["text"], "videoId": vr["videoId"], "author": vr["ownerText"]?["runs"]?[0]?["text"]?? "YT"});
            }
          }
          if (vids.isNotEmpty) { addLog("SUCCESS jalur 2"); setState(() { load = false; }); return; }
        }
      }
    } catch (e) { addLog("ERROR jalur 2: $e"); }

    // 3-5 GET APIS
    for (int i = 0; i < apis.length; i++) {
      try {
        addLog("3/${i+3} TRY GET ${apis[i]}$q");
        var r = await http.get(Uri.parse("${apis[i]}${Uri.encodeComponent(q)}")).timeout(const Duration(seconds: 12));
        addLog("3/${i+3} RESP Status:${r.statusCode} Length:${r.body.length}");
        if (r.statusCode == 200) {
          var j = jsonDecode(r.body);
          if (j is List && j.isNotEmpty) {
            for (var it in j) { vids.add({"title": it["title"]?? "No Title", "videoId": it["videoId"], "author": it["author"]?? "Invidious"}); }
            addLog("SUCCESS jalur ${i+3} dapet ${vids.length}");
            setState(() { load = false; }); return;
          }
        }
      } catch (e) { addLog("ERROR jalur ${i+3}: $e"); }
    }

    addLog("SEMUA JALUR GAGAL - cek log di atas");
    setState(() { load = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("NgalongTube V6 - Animein"), backgroundColor: Colors.red[900]),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(8), child: Row(children: [
          Expanded(child: TextField(controller: _c, decoration: const InputDecoration(hintText: "Cari video...", border: OutlineInputBorder()))),
          IconButton(onPressed: load? null : () => search(_c.text), icon: const Icon(Icons.search))
        ])),
        if (load) const LinearProgressIndicator(),
        if (showLog) Container(height: 150, color: Colors.black, child: ListView.builder(itemCount: logs.length, itemBuilder: (c, i) => Text(logs[i], style: const TextStyle(color: Colors.green, fontSize: 11)))),
        Expanded(child: vids.isEmpty? Center(child: Text(logs.isEmpty? "Mulai search..." : "0 video - cek log di atas", style: TextStyle(color: Colors.grey[600]))) : ListView.builder(itemCount: vids.length, itemBuilder: (c, i) {
          return ListTile(
            leading: Image.network("https://i.ytimg.com/vi/${vids[i]['videoId']}/mqdefault.jpg", width: 90, errorBuilder: (c, e, s) => Container(width: 90, color: Colors.grey)),
            title: Text(vids[i]['title'], maxLines: 2, style: const TextStyle(fontSize: 12)),
            subtitle: Text(vids[i]['author']?? '', style: const TextStyle(color: Colors.grey, fontSize: 11)),
            onTap: () => launchUrl(Uri.parse("https://www.youtube.com/watch?v=${vids[i]['videoId']}"), mode: LaunchMode.externalApplication),
          );
        }))
      ]),
    );
  }
}
