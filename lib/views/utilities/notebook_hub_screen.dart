import 'package:flutter/material.dart';
import '../../core/sl_theme.dart';
import 'shared_notes_screen.dart';
import 'bucket_list_screen.dart';
import 'wishlist_screen.dart';

class NotebookHubScreen extends StatelessWidget {
  final String houseId;
  final String myName;

  const NotebookHubScreen({
    super.key,
    required this.houseId,
    required this.myName,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: const BackButton(color: SLColors.primaryActive),
          title: Text(
            'Sổ tay kỷ niệm chung 📔',
            style: SLTheme.quicksand(
              fontWeight: FontWeight.w900,
              fontSize: 20,
              color: SLColors.textPrimary,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.download_rounded, color: SLColors.primaryActive),
              onPressed: () {},
            ),
          ],
          bottom: TabBar(
            labelColor: SLColors.primaryActive,
            unselectedLabelColor: Colors.grey,
            indicatorColor: SLColors.primaryActive,
            labelStyle: SLTheme.quicksand(fontWeight: FontWeight.w800),
            tabs: const [
              Tab(text: 'Ghi chú'),
              Tab(text: 'Bucket List'),
              Tab(text: 'Wish List'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            SharedNotesScreen(houseId: houseId, myName: myName),
            BucketListScreen(houseId: houseId, myName: myName),
            WishlistScreen(houseId: houseId, myName: myName),
          ],
        ),
      ),
    );
  }
}
