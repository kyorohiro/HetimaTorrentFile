library app;

import 'dart:html' as html;
import 'dart:async' as async;
import 'dart:convert' as convert;
import 'package:chrome/chrome_app.dart' as chrome;
import 'package:dart_web_toolkit/event.dart' as event;
import 'package:dart_web_toolkit/ui.dart' as ui;
import 'package:dart_web_toolkit/util.dart' as util;
import 'package:dart_web_toolkit/i18n.dart' as i18n;
import 'package:dart_web_toolkit/text.dart' as text;
import 'package:dart_web_toolkit/scheduler.dart' as scheduler;
import 'package:dart_web_toolkit/validation.dart' as validation;

import 'package:hetima/hetima_cl.dart' as hetimacl;
import 'package:hetima/hetima.dart' as hetima;
import 'dart:js' as js;
part './mainview.dart';
part './loadpanel.dart';
part './createpanel.dart';

MainView mView = new MainView();
void main() {
  mView.intialize();
  mView.onSelectTorrentFile.listen((FileSelectResult r) {
    loadTorrentFile(r);
  });

  mView.onSelectRawFile.listen((FileSelectResult r) {
    createTorrentFile(r);
  });
}

void createTorrentFile(FileSelectResult r) {
  hetima.TorrentFileCreator creator = new hetima.TorrentFileCreator();
  creator.announce = mView.announce;
  creator.piececLength = mView.pieceLength;
  creator.createFromSingleFile(r.file).then((hetima.TorrentFileCreatorResult r) {
    hetimacl.HetimaFileFS fsfile = new hetimacl.HetimaFileFS(creator.name + ".torrent");
    fsfile.getLength().then((int length) {
      List<int> buffer = hetima.Bencode.encode(r.torrentFile.mMetadata);
      return fsfile.write(buffer, 0).then((hetima.WriteResult r) {
        return fsfile.truncate(buffer.length);
      });
    }).then((int fileSize) {
      return fsfile.getEntry();
    }).then((html.Entry e) {
      html.FileEntry fentry = (e as html.FileEntry);
      return fentry.file().then((html.File f) {
        mView.downloadHref = e.toUrl();
        mView.downloadFile = f;
      });
    });
  });
}

void loadTorrentFile(FileSelectResult r) {
  hetima.HetimaBuilder builder = new hetima.HetimaFileToBuilder(r.file);
  hetima.TorrentFile.createTorrentFileFromTorrentFile(builder).then((hetima.TorrentFile f) {
    f.createInfoSha1().then((List<int> sha1hash) {
      StringBuffer buffer = new StringBuffer();
      buffer.write("announce = ${f.announce} <br>");
      buffer.write("piece length = ${f.info.piece_length} <br>");
      buffer.write("piece data length = ${f.info.pieces.length} <br>");
      buffer.write("files size = ${f.info.files.dataSize} <br>");
      buffer.write("num of files = ${f.info.files.numOfFiles} <br>");
      int pieceLen = (f.info.pieces.length ~/ 20);

      // piece list
      for (int i = 0; i < pieceLen; i++) {
        if (i < 10 || i + 1 == pieceLen) {
          buffer.write("pieces[${i}] = ");
          for (int k = 0; k < 20; k++) {
            buffer.write("${f.info.pieces[i*20+k].toRadixString(16)}");
          }
          buffer.write("<br>");
        }
      }
      // file list
      int j = 0;
      for (hetima.TorrentFileFile ff in f.info.files.path) {
        buffer.write("file[${j}] = ${ff.pathAsString} , ${ff.length} <br>");
        j++;
      }

      // info dic hash
      buffer.write("info dic hash = ");
      for (int v in sha1hash) {
        buffer.write("${v.toRadixString(16)}");
      }
      buffer.write("<br>");
      mView.torrentInfo = buffer.toString();
    });
  }).catchError((e) {
    ui.DialogBox dialog = createDialogBox("failed to load", new ui.Html("${r.fname}"));
    dialog.center();
    dialog.show();
  });
}
