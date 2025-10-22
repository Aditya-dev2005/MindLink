import 'package:flutter/material.dart';
import 'package:mindlink/constants.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mindlink/screens/welcome_screen.dart';
import 'package:mindlink/screens/focus_mode_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mindlink/services/encryption_service.dart';
import 'package:mindlink/services/ai_service.dart';

final _firestore = FirebaseFirestore.instance;

class ChatScreen extends StatefulWidget {
  static const String id = 'chat_screen';

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _auth = FirebaseAuth.instance;
  User? loggedInUser;
  String messageText = "";
  final TextEditingController messageController = TextEditingController();
  List<Map<String, dynamic>> chatMessages = [];
  String chatSentiment = '😐 Neutral';
  bool isGeneratingSummary = false;

  @override
  void initState() {
    super.initState();
    getCurrentUser();
  }

  void getCurrentUser() {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        loggedInUser = user;
        print('Logged in as: ${loggedInUser!.email}');
      }
    } catch (e) {
      print('Error fetching current user: $e');
    }
  }

  void _analyzeChatSentiment(List<Map<String, dynamic>> messages) {
    if (messages.isEmpty) return;

    final messageTexts = messages.map((msg) {
      // Use original text if available, otherwise use text directly
      if (msg['original_text'] != null) {
        return msg['original_text'].toString();
      } else {
        return msg['text'].toString();
      }
    }).toList();

    print('Analyzing sentiment for ${messageTexts.length} messages');

    // Use real AI sentiment analysis with fallback
    AIService.analyzeSentimentReal(messageTexts).then((sentiment) {
      if (mounted) {
        setState(() {
          chatSentiment = sentiment;
        });
      }
    }).catchError((e) {
      print('Gemini sentiment failed, using fallback: $e');
      // Fallback to basic analysis
      if (mounted) {
        setState(() {
          chatSentiment = AIService.analyzeSentiment(messageTexts);
        });
      }
    });
  }

  void _checkForReminders(String message) async {
    print('Checking for reminders in: $message');

    try {
      // Try AI reminder detection first
      final reminders = await AIService.extractRemindersAI(message);
      print('AI found reminders: $reminders');

      if (reminders.isNotEmpty) {
        _showReminderAlert(reminders.first);
        return;
      }
    } catch (e) {
      print('AI reminder detection failed: $e');
    }

    // Fallback to regex detection
    final regexReminders = AIService.extractReminders(message);
    print('Regex found reminders: $regexReminders');

    if (regexReminders.isNotEmpty) {
      _showReminderAlert(regexReminders.first);
    }
  }

  void _showReminderAlert(String reminder) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('🔔 Smart Reminder',
            style: TextStyle(color: Colors.deepPurple)),
        content: Text('I detected a reminder: "$reminder"',
            style: TextStyle(color: Colors.black87)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Dismiss', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              // Save to reminders
              _firestore.collection('reminders').add({
                'text': reminder,
                'user': loggedInUser?.email,
                'created_at': FieldValue.serverTimestamp(),
                'completed': false,
              });
              Navigator.pop(context);
              _showReminderSaved();
            },
            child: Text('Save Reminder',
                style: TextStyle(color: Colors.deepPurple)),
          ),
        ],
      ),
    );
  }

  void _showReminderSaved() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ Reminder saved!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  // SIMPLE notification feature - no external dependencies
  void _showLocalNotification(String title, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
            Text(message),
          ],
        ),
        backgroundColor: Colors.blue.shade700,
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Check for mentions and show notifications
  void _checkForMentions(String message) {
    final mentionPattern = RegExp(r'@(\w+)');
    final mentions = mentionPattern.allMatches(message);

    for (final match in mentions) {
      final mentionedUser = match.group(1);
      _showLocalNotification(
        '📨 Mention Alert',
        'You mentioned @$mentionedUser in your message',
      );
    }

    // Check for urgent keywords
    final urgentKeywords = ['urgent', 'important', 'asap', 'emergency'];
    if (urgentKeywords.any((word) => message.toLowerCase().contains(word))) {
      _showLocalNotification(
        '🚨 Important Message',
        'You sent an important message',
      );
    }
  }

  Future<void> _generateChatSummary() async {
    setState(() {
      isGeneratingSummary = true;
    });

    try {
      print('Generating summary for ${chatMessages.length} messages');
      final summary = await AIService.generateChatSummary(chatMessages);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white,
          title: Text('🧠 AI Chat Summary',
              style: TextStyle(color: Colors.deepPurple)),
          content: SingleChildScrollView(
            padding: EdgeInsets.all(10),
            child: Text(
              summary,
              style:
                  TextStyle(fontSize: 14, height: 1.4, color: Colors.black87),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close', style: TextStyle(color: Colors.deepPurple)),
            ),
          ],
        ),
      );
    } catch (e) {
      print('Error generating summary: $e');
      // Show error to user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate summary. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isGeneratingSummary = false;
        });
      }
    }
  }

  void _sendMessage() {
    if (messageText.trim().isNotEmpty && loggedInUser != null) {
      try {
        // For now, send without encryption to fix AI features
        _firestore.collection('messages').add({
          'text': messageText,
          'sender': loggedInUser!.email,
          'timestamp': FieldValue.serverTimestamp(),
          'is_encrypted': false,
        });

        // Check for mentions and show notifications
        _checkForMentions(messageText);

        messageController.clear();
        setState(() {
          messageText = "";
        });

        print('Message sent successfully!');
      } catch (e) {
        print('Error sending message: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: null,
        actions: <Widget>[
          // Focus Mode Button
          IconButton(
            icon: Icon(Icons.timer, color: Colors.white),
            onPressed: () {
              Navigator.pushNamed(context, FocusModeScreen.id);
            },
            tooltip: 'Focus Mode',
          ),
          // AI Summary Button
          IconButton(
            icon: Icon(
              isGeneratingSummary ? Icons.hourglass_empty : Icons.summarize,
              color: Colors.white,
            ),
            onPressed: isGeneratingSummary ? null : _generateChatSummary,
            tooltip: 'Generate AI Summary (Gemini)',
          ),
          // Notification Test Button (Safe)
          IconButton(
            icon: Icon(Icons.notifications, color: Colors.white),
            onPressed: () {
              _showLocalNotification(
                '🔔 MindLink Notifications',
                'Notification system is active! Try mentioning someone with @username',
              );
            },
            tooltip: 'Test Notifications',
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () async {
              await _auth.signOut();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => WelcomeScreen()),
              );
            },
          ),
        ],
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('⚡️MindLink',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            Text(
              chatSentiment,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                  color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: Colors.blue.shade700, // Brighter blue
        elevation: 8,
        shadowColor: Colors.blue.shade200,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade50, Colors.white],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: MessageStream(
                  loggedInUser: loggedInUser,
                  onMessagesUpdated: (messages) {
                    setState(() {
                      chatMessages = messages;
                    });
                    _analyzeChatSentiment(messages);
                  },
                  onNewMessage: _checkForReminders,
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Expanded(
                      child: Container(
                        margin: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: TextField(
                          controller: messageController,
                          onChanged: (value) {
                            setState(() {
                              messageText = value;
                            });
                          },
                          onSubmitted: (value) => _sendMessage(),
                          style: TextStyle(color: Colors.black),
                          decoration: InputDecoration(
                            hintText:
                                'Type your message... (Use @username for mentions)',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            hintStyle: TextStyle(color: Colors.grey.shade600),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      margin: EdgeInsets.only(right: 8),
                      child: CircleAvatar(
                        backgroundColor: Colors.blue.shade700,
                        child: IconButton(
                          onPressed: _sendMessage,
                          icon: Icon(Icons.send, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MessageStream extends StatelessWidget {
  final User? loggedInUser;
  final Function(List<Map<String, dynamic>>)? onMessagesUpdated;
  final Function(String)? onNewMessage;

  const MessageStream(
      {this.loggedInUser, this.onMessagesUpdated, this.onNewMessage, Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('messages')
          .orderBy('timestamp', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade700),
            ),
          );
        }

        final messages = snapshot.data!.docs;
        List<Map<String, dynamic>> messageData = [];
        List<MessageBubble> messageBubbles = [];

        for (var message in messages) {
          final data = message.data() as Map<String, dynamic>;
          messageData.add(Map<String, dynamic>.from(data)); // Create a copy

          String messageText = data['text'].toString();
          final messageSender = data['sender'].toString();
          final isEncrypted = data['is_encrypted'] == true;

          // Decrypt message if encrypted
          if (isEncrypted) {
            try {
              messageText = EncryptionService.decryptMessage(messageText);
            } catch (e) {
              messageText = '🔒 Unable to decrypt message';
              print('Decryption error: $e');
            }
          }

          final messageBubble = MessageBubble(
            sender: messageSender,
            text: messageText,
            isMe: loggedInUser?.email == messageSender,
            isEncrypted: isEncrypted,
          );
          messageBubbles.add(messageBubble);
        }

        // Notify parent about messages for AI analysis
        if (onMessagesUpdated != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            onMessagesUpdated!(messageData);
          });
        }

        // Check latest message for reminders
        if (messageData.isNotEmpty && onNewMessage != null) {
          final latestMessage = messageData.last;
          final messageText =
              latestMessage['original_text'] ?? latestMessage['text'];

          WidgetsBinding.instance.addPostFrameCallback((_) {
            onNewMessage!(messageText.toString());
          });
        }

        return ListView(
          reverse: true,
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 20.0),
          children: messageBubbles.reversed.toList(),
        );
      },
    );
  }
}

class MessageBubble extends StatelessWidget {
  const MessageBubble(
      {required this.sender,
      required this.text,
      required this.isMe,
      this.isEncrypted = false,
      Key? key})
      : super(key: key);

  final String sender;
  final String text;
  final bool isMe;
  final bool isEncrypted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Sender name - more visible
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: isMe ? Colors.blue.shade100 : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              sender.split('@')[0], // Show only username part of email
              style: TextStyle(
                fontSize: 11.0,
                color: isMe ? Colors.blue.shade800 : Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Material(
            borderRadius: isMe
                ? const BorderRadius.only(
                    topLeft: Radius.circular(20.0),
                    bottomLeft: Radius.circular(20.0),
                    bottomRight: Radius.circular(20.0))
                : const BorderRadius.only(
                    topRight: Radius.circular(20.0),
                    bottomLeft: Radius.circular(20.0),
                    bottomRight: Radius.circular(20.0)),
            elevation: 3.0,
            color: isMe ? Colors.blue.shade600 : Colors.white,
            shadowColor: Colors.black26,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isEncrypted)
                    Row(
                      children: [
                        Icon(Icons.lock,
                            size: 12,
                            color:
                                isMe ? Colors.white70 : Colors.blue.shade600),
                        SizedBox(width: 4),
                        Text(
                          'Encrypted',
                          style: TextStyle(
                            fontSize: 10,
                            color: isMe ? Colors.white70 : Colors.blue.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  SizedBox(height: isEncrypted ? 4 : 0),
                  Text(
                    text,
                    style: TextStyle(
                      fontSize: 15.0,
                      color: isMe ? Colors.white : Colors.black87,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
