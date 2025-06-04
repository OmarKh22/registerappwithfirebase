import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'login_screen.dart';

class HomeScreen extends StatelessWidget {
  final AuthService _auth = AuthService();
  final user = FirebaseAuth.instance.currentUser;

  void _addComment(BuildContext context, String postId) {
    final TextEditingController _commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Add Comment'),
        content: TextField(
          controller: _commentController,
          decoration: InputDecoration(hintText: 'Type your comment...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final comment = _commentController.text.trim();
              if (comment.isNotEmpty) {
                await FirebaseFirestore.instance
                    .collection('posts')
                    .doc(postId)
                    .update({
                      'comments': FieldValue.arrayUnion([comment]),
                    });
              }
              Navigator.pop(context);
            },
            child: Text('Add'),
          ),
        ],
      ),
    );
  }

  void _likePost(String postId) async {
    final postRef = FirebaseFirestore.instance.collection('posts').doc(postId);
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(postRef);
      final currentLikes = snapshot['likes'] ?? 0;
      transaction.update(postRef, {'likes': currentLikes + 1});
    });
  }

  void _editPost(
    BuildContext context,
    String postId,
    String currentTitle,
    String currentDesc,
  ) {
    final TextEditingController _titleController = TextEditingController(
      text: currentTitle,
    );
    final TextEditingController _descController = TextEditingController(
      text: currentDesc,
    );

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Edit Post'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(hintText: 'Title'),
            ),
            TextField(
              controller: _descController,
              decoration: InputDecoration(hintText: 'Description'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('posts')
                  .doc(postId)
                  .update({
                    'title': _titleController.text.trim(),
                    'description': _descController.text.trim(),
                  });
              Navigator.pop(context);
            },
            child: Text('Save'),
          ),
        ],
      ),
    );
  }

  void _deletePost(BuildContext context, String postId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete Post'),
        content: Text('Are you sure you want to delete this post?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('posts').doc(postId).delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Welcome, ${user != null ? user!.email!.split('@')[0] : ''}',
        ),
        actions: [
          IconButton(
            onPressed: () {
              final TextEditingController _titleController =
                  TextEditingController();
              final TextEditingController _descController =
                  TextEditingController();

              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: Text('Add New Post'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: _titleController,
                        decoration: InputDecoration(hintText: 'Title'),
                      ),
                      TextField(
                        controller: _descController,
                        decoration: InputDecoration(hintText: 'Description'),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        final title = _titleController.text.trim();
                        final desc = _descController.text.trim();
                        if (title.isNotEmpty && desc.isNotEmpty) {
                          await FirebaseFirestore.instance
                              .collection('posts')
                              .add({
                                'title': title,
                                'description': desc,
                                'name':
                                    user?.email?.split('@')[0] ??
                                    'Unknown User',
                                'createdAt': FieldValue.serverTimestamp(),
                                'likes': 0,
                                'comments': [],
                              });
                          Navigator.pop(context);
                        }
                      },
                      child: Text('Add'),
                    ),
                  ],
                ),
              );
            },
            icon: Icon(Icons.add),
          ),
          IconButton(
            onPressed: () async {
              await _auth.signOut();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => LoginScreen()),
              );
            },
            icon: Icon(Icons.logout),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('posts')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return Center(child: Text('Error: ${snapshot.error}'));
          if (snapshot.connectionState == ConnectionState.waiting)
            return Center(child: CircularProgressIndicator());

          final posts = snapshot.data!.docs;

          return ListView.builder(
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              final data = post.data() as Map<String, dynamic>;
              final comments = (data['comments'] ?? []) as List;

              return Card(
                margin: EdgeInsets.all(10),
                child: Padding(
                  padding: EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              data['title'] ?? '',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.edit, color: Colors.orange),
                            onPressed: () => _editPost(
                              context,
                              post.id,
                              data['title'] ?? '',
                              data['description'] ?? '',
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deletePost(context, post.id),
                          ),
                        ],
                      ),
                      SizedBox(height: 5),
                      Text(data['description'] ?? ''),
                      SizedBox(height: 5),
                      Text(
                        "By: ${data['name'] ?? ''}",
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      SizedBox(height: 10),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.favorite, color: Colors.red),
                            onPressed: () => _likePost(post.id),
                          ),
                          Text('${data['likes'] ?? 0}'),
                          SizedBox(width: 16),
                          IconButton(
                            icon: Icon(Icons.comment, color: Colors.blue),
                            onPressed: () => _addComment(context, post.id),
                          ),
                          Text('${comments.length}'),
                        ],
                      ),
                      if (comments.isNotEmpty) ...[
                        Divider(),
                        Text(
                          'Comments:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        ...comments.map(
                          (comment) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Text("• $comment"),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
