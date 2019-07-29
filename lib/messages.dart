import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:majora/emotes.dart';

class MessageList extends StatelessWidget {
  final ScrollController _controller = ScrollController();
  final List<Message> _messages;

  MessageList(this._messages);

  _launchURL(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      reverse: true,
      controller: _controller,
      itemCount: _messages.length,
      itemBuilder: (BuildContext ctx, int index) {
        Message msg = _messages[index];

        var output = <InlineSpan>[];

        var ts = TextSpan(
            text: msg.readTimestamp() + " ",
            style: TextStyle(color: Colors.blueGrey[700]));

        output.add(ts);

        var nick;
        switch (msg.type) {
          case "PRIVMSG":
            nick = TextSpan(
                text: msg.nick + " whispered: ",
                style:
                    TextStyle(background: Paint()..color = Colors.blue[400]));
            break;
          default:
            nick = TextSpan(
                text: msg.nick + ": ",
                style:
                    TextStyle(background: Paint()..color = Colors.grey[900]));
        }

        output.add(nick);

        // TODO: do this properly
        if (msg.data.subSegements != null) {
          msg.data.subSegements.forEach((val) {
            // if type text, render text text span
            // if type emote, render img span
            // output.add(x);
            switch (val.type) {
              case "text":
                TextSpan x = TextSpan(
                    text: val.data.toString(),
                    style: TextStyle(color: Colors.grey[400]));
                output.add(x);
                break;
              case "emote":
                AssetImage img = AssetImage('assets/${val.data}');
                Image x = Image(
                  image: img,
                  height: 32,
                );
                output.add(WidgetSpan(child: x));
                break;
              case "url":
                //URL styling // there has to be a better way to do this
                var styleURL = TextStyle(
                    color: Colors.blue[400],
                    decoration: TextDecoration.underline);

                if (val.getLinkModifier != null) {
                  switch (val.getLinkModifier) {
                    case "nsfl":
                      styleURL = TextStyle(
                          color: Colors.blue[400],
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.yellow[400],
                          decorationStyle: TextDecorationStyle.dashed);
                      break;
                    case "nsfw":
                      styleURL = TextStyle(
                          color: Colors.blue[400],
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.red[400],
                          decorationStyle: TextDecorationStyle.dashed);
                      break;
                    case "loud":
                      styleURL = TextStyle(
                          color: Colors.blue[400],
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.blue[400],
                          decorationStyle: TextDecorationStyle.dashed);
                      break;
                    case "weeb":
                      styleURL = TextStyle(
                          color: Colors.blue[400],
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.purple[400],
                          decorationStyle: TextDecorationStyle.dashed);
                      break;
                  }
                }
                //URL styling
                TextSpan x = TextSpan(
                  text: val.data.toString(),
                  style: styleURL,
                  recognizer: new TapGestureRecognizer()
                    ..onTap = () => {_launchURL(val.data.toString())},
                );
                output.add(x);
                break;
              case "code":
                TextSpan x = TextSpan(
                    text: val.data.toString(),
                    style: TextStyle(color: Colors.grey[400]));
                output.add(x);
                break;
              default:
                TextSpan x = TextSpan(
                    text: val.toString(),
                    style: TextStyle(color: Colors.grey[400]));
                output.add(x);
                break;
            }
          });
        }

        return Card(
            color: Colors.transparent,
            child: Text.rich(TextSpan(children: output)));
      },
    );
  }
}

class Message {
  String type;
  String nick;
  int timestamp;
  MessageSegment data;
  static const List linkModifiers = ['nsfl', 'nsfw', 'loud', 'weeb'];
  Message({this.type, this.nick, this.timestamp, this.data});

  String readTimestamp() {
    if (this.timestamp != 0) {
      DateTime d =
          new DateTime.fromMillisecondsSinceEpoch(this.timestamp, isUtc: true);
      String hour = d.hour.toString();
      String minute = d.minute.toString();
      if (hour.length == 1) {
        hour = "0" + hour;
      }
      if (minute.length == 1) {
        minute = "0" + minute;
      }
      return "$hour:$minute";
    }
    return "";
  }

  factory Message.fromJson(String type, Map parsedJson) {
    // ignore escaped backticks
    int _findNextTick(String str) {
      int base = 0;
      while (str.length > 0) {
        var index = str.indexOf('`');
        if (index == -1) {
          return -1;
        } else if (index - 1 >= 0 && str[(index - 1)] == '\\') {
          base += index + 1;
          str = str.substring(index + 1);
        } else {
          return index + base;
        }
      }
      return -1;
    }

    List<MessageSegment> _tokenizeCode(String str) {
      List<MessageSegment> returnList = new List<MessageSegment>();
      int indexOne = _findNextTick(str);
      if (indexOne != -1) {
        String beforeFirstTick = str.substring(0, indexOne);
        String afterFirstTick = str.substring(indexOne + 1);
        int indexTwo = _findNextTick(afterFirstTick);
        if (indexTwo != -1) {
          String betweenTicks = afterFirstTick.substring(0, indexTwo);
          String afterSecondTick = afterFirstTick.substring(indexTwo + 1);
          if (beforeFirstTick.length > 0) {
            returnList.add(new MessageSegment('text', beforeFirstTick));
          }
          returnList.add(new MessageSegment('code', betweenTicks));
          if (afterSecondTick.length > 0) {
            returnList.addAll(_tokenizeCode(afterSecondTick));
          }
        }
      } else {
        returnList.add(new MessageSegment('text', str));
      }
      return returnList;
    }

    _recursiveCode(MessageSegment base) {
      if (base.type == 'text' && base.subSegemnts == null) {
        base.subSegemnts = _tokenizeCode(base.data);
        base.data = '';
      } else if (base.subSegemnts != null) {
        for (MessageSegment segment in base.subSegemnts) {
          _recursiveCode(segment);
        }
      }
    }

    _tokenizeGreentext(MessageSegment base) {
      if (base.type == "text" && base.subSegemnts == null) {
        RegExp greenReg = new RegExp(r'^\s*>.*$');
        if (greenReg.hasMatch(base.data)) {
          base.modifier = 'green';
        }
      } else if (base.subSegemnts != null) {
        for (MessageSegment segment in base.subSegemnts) {
          _tokenizeGreentext(segment);
        }
      }
    }

    MessageSegment _tokenizeSelf(String str) {
      if (str.length >= 3 && str.substring(0, 3) == '/me') {
        return new MessageSegment('self', str.substring(3));
      }
      return new MessageSegment('regular', str);
    }

    List<MessageSegment> _tokenizeSpoiler(String str) {
      List<MessageSegment> returnList = new List<MessageSegment>();
      var indexOne = str.indexOf('||');
      if (indexOne != -1) {
        var afterTag = str.substring(indexOne + 2);
        var indexTwo = afterTag.indexOf('||');
        if (indexTwo != -1) {
          var betweenTags = afterTag.substring(0, indexTwo);
          if (new RegExp(r'^\s*$').hasMatch(betweenTags)) {
            returnList.add(new MessageSegment(
                'text', str.substring(0, indexOne) + '||||'));
          } else {
            returnList.add(new MessageSegment('text',
                str.substring(0, indexOne) + str.substring(0, indexOne)));
            returnList.add(new MessageSegment('spoiler', betweenTags));
            returnList
                .addAll(_tokenizeSpoiler(afterTag.substring(indexTwo + 2)));
          }
        }
      } else {
        returnList.add(new MessageSegment('text', str));
      }
      return returnList;
    }

    _tokenizeEmotes(MessageSegment base) {
      List<MessageSegment> returnList = new List<MessageSegment>();
      String tmpBuffer = "";
      bool foundEmote = false;
      if (base.type == 'text' && base.subSegemnts == null) {
        for (String segment in base.data.split(" ")) {
          List<String> colonSplit = segment.split(":");
          if (colonSplit.length == 1 && kEmotes.containsKey(segment)) {
            foundEmote = true;
            if (tmpBuffer.length > 0) {
              returnList.add(new MessageSegment("text", tmpBuffer + " "));
            }
            tmpBuffer = "";
            returnList.add(new MessageSegment("emote", segment));
          } else if (colonSplit.length == 2 &&
              kEmotes.containsKey(colonSplit[0]) &&
              kEmoteModifiers.contains(colonSplit[1])) {
            foundEmote = true;
            if (tmpBuffer.length > 0) {
              returnList.add(new MessageSegment("text", tmpBuffer + " "));
            }
            tmpBuffer = "";
            returnList.add(new MessageSegment("emote", colonSplit[0],
                modifier: colonSplit[1]));
          } else {
            tmpBuffer += " " + segment;
          }
        }
        if (tmpBuffer.length > 0) {
          returnList.add(new MessageSegment("text", tmpBuffer + " "));
        }
        if (foundEmote) {
          base.data = "";
          base.subSegemnts = returnList;
        }
      } else if (base.subSegemnts != null) {
        for (MessageSegment segment in base.subSegemnts) {
          _tokenizeEmotes(segment);
        }
      }
    }

    _tokenizeLinks(MessageSegment base) {
      if (base.type == 'text' && base.subSegemnts == null) {
        RegExp reg = new RegExp(
            r'(http(s)?:\/\/.)?(www\.)?[-a-zA-Z0-9@:%._\+~#=]{2,256}\.[a-z]{2,20}\b([-a-zA-Z0-9@:%_\+.~#?&//=]*)');
        List<MessageSegment> newSegments = new List<MessageSegment>();
        Iterable<RegExpMatch> matches = reg.allMatches(base.data);
        if (matches.length > 0) {
          List<String> withoutUrls = base.data.split(reg);
          for (var i = 0; i < withoutUrls.length; i++) {
            if (withoutUrls[i].length > 0) {
              newSegments.add(new MessageSegment('text', withoutUrls[i]));
            }
            if (matches.length > i) {
              newSegments.add(
                  new MessageSegment('url', matches.elementAt(i).group(0)));
            }
          }
          base.subSegemnts = newSegments;
          base.data = "";
        }
      } else if (base.subSegemnts != null) {
        for (MessageSegment segment in base.subSegemnts) {
          _tokenizeLinks(segment);
        }
      }
    }

    _flattenTree(MessageSegment base) {
      if (base.subSegemnts != null) {
        List<MessageSegment> newList = [];
        for (MessageSegment s1 in base.subSegemnts) {
          _flattenTree(s1);
          if (s1.type == 'text' &&
              s1.modifier == null &&
              s1.subSegemnts != null) {
            bool canFlatten = true;
            List<MessageSegment> tmpList = [];
            for (MessageSegment s2 in s1.subSegemnts) {
              tmpList.add(s2);
            }
            if (canFlatten) {
              newList.addAll(tmpList);
            } else {
              newList.add(s1);
            }
          } else {
            newList.add(s1);
          }
        }
        base.subSegemnts = newList;
      }
    }

    MessageSegment _tokenizeMessage(String message) {
      // get /me
      MessageSegment base = _tokenizeSelf(message);
      // get spoiler blocks
      List<MessageSegment> tmp = _tokenizeSpoiler(base.data);
      base.data = '';
      base.subSegemnts = tmp;
      _recursiveCode(base);
      _tokenizeGreentext(base);
      _tokenizeLinks(base);
      _tokenizeEmotes(base);
      _flattenTree(base);

      return base;
    }

    Set<String> recDetermineLinkModfier(
        MessageSegment message, Set<String> modifierSet) {
      // Set<String> modifierSet = new Set();
      // print(message.toString());
      if (message.subSegemnts != null) {
        message.subSegemnts.forEach((subSegment) {
          if (subSegment.subSegements != null) {
            modifierSet.addAll(
                recDetermineLinkModfier(subSegment, modifierSet)); // rec down

          } else {
            if (subSegment.data.trim().length >= 4) {
              for (var linkMod in linkModifiers) {
                if (subSegment.data.contains(linkMod)) {
                  print(linkMod);
                  modifierSet.add(linkMod);
                  break; // we don't need to search any longer as the importance is front loaded
                }
              }
            }
          }
        });
      }
      return modifierSet;
    }

    _recAttatchLinkModifiers(MessageSegment message, String linkModifier) {
      if (message.subSegemnts != null) {
        message.subSegemnts.forEach((subSegment) {
          if (subSegment.subSegements != null) {
            _recAttatchLinkModifiers(subSegment, linkModifier); // rec down

          } else {
            if (subSegment.type == "url") {
              subSegment.linkModifier = linkModifier;
            }
          }
        });
      }
    }

    _attatchLinkModifiers(MessageSegment message) {
      Set<String> linkModSet = new Set();
      linkModSet = recDetermineLinkModfier(message, linkModSet);
      for (var mod in linkModifiers) {
        if (linkModSet.contains(mod)) {
          _recAttatchLinkModifiers(message, mod);
          break; // attach only most important modifier
        }
      }
    }

    MessageSegment message = _tokenizeMessage(parsedJson['data']);
    _attatchLinkModifiers(message);
    return Message(
        type: type,
        nick: parsedJson['nick'],
        timestamp: parsedJson['timestamp'],
        data: message);
  }
}

class MessageSegment {
  String type;
  String data;
  String linkModifier;
  String modifier;
  List<MessageSegment> subSegemnts;
  get getLinkModifier => linkModifier;
  get subSegements => subSegemnts;

  @override
  String toString() {
    return toStringIndent(1);
  }

  String toStringIndent(int depth) {
    String segs = '';
    if (subSegemnts != null) {
      for (MessageSegment segment in subSegemnts) {
        segs += '    ' * depth + segment.toStringIndent(depth + 1) + '\n';
      }
    }
    String dataS = (data.length > 0) ? ', data: "' + data + '" ' : '';
    String mod = (modifier != null) ? ', mod: ' + modifier : '';
    String newline =
        (segs.length > 0) ? '\n' + segs + '    ' * (depth - 1) + ']}' : ']}';
    return '{type: ' + type + mod + dataS + ', children: [' + newline;
  }

  String getData() {
    return data;
  }

  MessageSegment(this.type, this.data, {this.modifier, this.subSegemnts});
}
