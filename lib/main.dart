import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

void main()=>runApp(const MaterialApp(debugShowCheckedModeBanner:false, home:SearchPage()));

class SearchPage extends StatefulWidget{const SearchPage({super.key}); @override State<SearchPage> createState()=>_S();}
class _S extends State<SearchPage>{
  final _c=TextEditingController(text:"playlist ngalong malam");
  List vids=[]; List<String> logs=[]; bool load=false; bool showLog=true;

  void addLog(String s){
    final time="${DateTime.now().hour}:${DateTime.now().minute}:${DateTime.now().second}";
    setState(()=>logs.insert(0,"[$time] $s"));
    print("[$time] $s");
  }

  Future<void> search(String q) async {
    setState((){load=true; vids=[]; logs=[];});
    addLog("🚀 START search: $q");
    addLog("📱 DNS Private: ${await checkDNS()}");

    final headers={"User-Agent":"Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/120.0","Content-Type":"application/json","X-YouTube-Client-Name":"1","X-YouTube-Client-Version":"2.20240101.01.00"};

    // 1. YT WEB
    try{
      addLog("1/5 TRY POST https://www.youtube.com/youtubei/v1/search [WEB]");
      var r=await http.post(Uri.parse("https://www.youtube.com/youtubei/v1/search?key=AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8"),
        headers: headers, body: jsonEncode({"context":{"client":{"clientName":"WEB","clientVersion":"2.20240101.01.00","hl":"id","gl":"ID"}},"query":q})
      ).timeout(const Duration(seconds:12));
      addLog("1/5 RESP Status:${r.statusCode} Length:${r.body.length} BodyPreview:${r.body.substring(0, r.body.length>200?200:r.body.length).replaceAll('\n',' ')}");
      if(r.statusCode==200 && r.body.contains("videoId")){
        var j=jsonDecode(r.body); var contents=j['contents']?['twoColumnSearchResultsRenderer']?['primaryContents']?['sectionListRenderer']?['contents']??[];
        List f=[]; for(var sec in contents){var items=sec['itemSectionRenderer']?['contents']??[]; for(var it in items){var vr=it['videoRenderer']; if(vr!=null) f.add({'videoId':vr['videoId'],'title':vr['title']?['runs']?[0]?['text'],'author':vr['ownerText']?['runs']?[0]?['text']});}}
        if(f.isNotEmpty){addLog("✅ SUCCESS jalur 1, dapet ${f.length} video"); setState((){vids=f.take(15).toList(); load=false;}); return;}
      } else {addLog("❌ FAIL jalur 1 - status bukan 200 atau ga ada videoId");}
    }catch(e,stack){addLog("💥 ERROR jalur 1: $e \n $stack");}

    // 2. YT ANDROID
    try{
      addLog("2/5 TRY POST YT [ANDROID]");
      var r=await http.post(Uri.parse("https://www.youtube.com/youtubei/v1/search?key=AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8"),
        headers: headers, body: jsonEncode({"context":{"client":{"clientName":"ANDROID","clientVersion":"19.09.36","androidSdkVersion":30}},"query":q})
      ).timeout(const Duration(seconds:12));
      addLog("2/5 RESP Status:${r.statusCode} Length:${r.body.length}");
      if(r.statusCode==200 && r.body.contains("videoId")){
        var j=jsonDecode(r.body); var contents=j['contents']?['twoColumnSearchResultsRenderer']?['primaryContents']?['sectionListRenderer']?['contents']??[];
        List f=[]; for(var sec in contents){var items=sec['itemSectionRenderer']?['contents']??[]; for(var it in items){var vr=it['videoRenderer']; if(vr!=null) f.add({'videoId':vr['videoId'],'title':vr['title']?['runs']?[0]?['text'],'author':vr['ownerText']?['runs']?[0]?['text']});}}
        if(f.isNotEmpty){addLog("✅ SUCCESS jalur 2"); setState((){vids=f.take(15).toList(); load=false;}); return;}
      }
    }catch(e){addLog("💥 ERROR jalur 2: $e");}

    // 3-5 GET APIS
    List<String> apis=["https://vid.puffyan.us/api/v1/search?q=","https://y.com.sb/api/v1/search?q=","https://pipedapi.kavin.rocks/search?q="];
    for(int i=0;i<apis.length;i++){
      try{
        addLog("${3+i}/5 TRY GET ${apis[i]}${q}");
        var r=await http.get(Uri.parse("${apis[i]}${Uri.encodeComponent(q)}"), headers: {"User-Agent":"Mozilla/5.0"}).timeout(const Duration(seconds:10));
        addLog("${3+i}/5 RESP Status:${r.statusCode} Length:${r.body.length} Preview:${r.body.substring(0, r.body.length>150?150:r.body.length)}");
        if(r.statusCode==200){
          var j=jsonDecode(r.body); var items=j is Map? (j['items']??j['content']??[]): j;
          if(items is List && items.isNotEmpty){List m=[]; for(var x in items){var id=(x['url']??'').toString().split('v=').last.split('&').first.replaceAll('/watch?v=',''); if(id.length>5) m.add({'videoId':id,'title':x['title'],'author':x['uploaderName']??x['author']});} if(m.isNotEmpty){addLog("✅ SUCCESS jalur ${3+i} ${apis[i]}"); setState((){vids=m.take(15).toList(); load=false;}); return;}}
        }
      }catch(e){addLog("💥 ERROR jalur ${3+i}: $e");}
    }
    addLog("❌ FINAL FAIL - semua 5 jalur gagal. Provider lu ngeblok semua.");
    setState(()=>load=false);
  }

  Future<String> checkDNS() async {try{var r=await http.get(Uri.parse("https://1.1.1.1/cdn-cgi/trace")).timeout(const Duration(seconds:3)); return "OK ${r.statusCode}";}catch(e){return "FAIL $e";}}

  @override void initState(){super.initState(); search(_c.text);}
  @override Widget build(BuildContext context){
    return Scaffold(backgroundColor:Colors.black, appBar:AppBar(title:const Text("😈 V12 DEV CONSOLE"), backgroundColor:Colors.black, actions:[IconButton(icon:const Icon(Icons.copy), onPressed:(){Clipboard.setData(ClipboardData(text:logs.join("\n"))); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text("Log dicopy!")));}), IconButton(icon:Icon(showLog?Icons.bug_report:Icons.bug_report_outlined), onPressed:()=>setState(()=>showLog=!showLog))]),
      body:Column(children:[
        Padding(padding:const EdgeInsets.all(12), child:TextField(controller:_c, onSubmitted:search, style:const TextStyle(color:Colors.white), decoration:InputDecoration(hintText:"cari...", hintStyle:const TextStyle(color:Colors.grey), filled:true, fillColor:Colors.white12, border:OutlineInputBorder(borderRadius:BorderRadius.circular(12)), suffixIcon:IconButton(icon:const Icon(Icons.search, color:Colors.white), onPressed:()=>search(_c.text))))),
        if(load) const LinearProgressIndicator(color:Colors.purple),
        if(showLog) Container(height:220, color:Colors.black87, child:Column(children:[
          Container(color:Colors.white10, padding:const EdgeInsets.all(6), child:Row(mainAxisAlignment:MainAxisAlignment.spaceBetween, children:[const Text("CONSOLE LOG (kayak F12)", style:TextStyle(color:Colors.greenAccent, fontSize:11)), Text("${logs.length} lines", style:const TextStyle(color:Colors.grey, fontSize:10))])),
          Expanded(child:ListView.builder(reverse:true, itemCount:logs.length, itemBuilder:(c,i){var l=logs[logs.length-1-i]; Color col=l.contains("✅")?Colors.greenAccent:l.contains("❌")||l.contains("💥")?Colors.redAccent:l.contains("TRY")?Colors.yellowAccent:Colors.white70; return Padding(padding:const EdgeInsets.symmetric(horizontal:8, vertical:2), child:Text(l, style:TextStyle(color:col, fontSize:10, fontFamily:'monospace')));}))
        ])),
        Expanded(child:vids.isEmpty &&!load? Center(child:Text(logs.isEmpty?"Mulai search...": "0 video - cek log di atas", style:const TextStyle(color:Colors.grey))) : ListView.builder(itemCount:vids.length, itemBuilder:(c,i){var v=vids[i]; return ListTile(leading:Image.network("https://i.ytimg.com/vi/${v['videoId']}/mqdefault.jpg", width:90, errorBuilder:(c,e,s)=>Container(width:90,color:Colors.grey)), title:Text(v['title']??'', maxLines:2, style:const TextStyle(fontSize:12, color:Colors.white)), subtitle:Text(v['author']??'', style:const TextStyle(color:Colors.grey)), onTap:()=>launchUrl(Uri.parse("https://www.youtube.com/watch?v=${v['videoId']}"), mode:LaunchMode.externalApplication));})),
      ]));
  }
}
