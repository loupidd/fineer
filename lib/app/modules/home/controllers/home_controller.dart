// ignore_for_file: unnecessary_overrides, unused_import

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class HomeController extends GetxController {
  RxBool isLoading = false.obs;

  FirebaseAuth auth = FirebaseAuth.instance;
  FirebaseFirestore firestore = FirebaseFirestore.instance;

  // Stream to fetch user data from Firestore
  Stream<DocumentSnapshot<Map<String, dynamic>>> streamUser() async* {
    if (auth.currentUser == null) {
      yield* const Stream.empty();
    } else {
      String uid = auth.currentUser!.uid;
      yield* firestore.collection("pegawai").doc(uid).snapshots();
    }
  }

  // Stream to get last 5 presence records for the user
  Stream<QuerySnapshot<Map<String, dynamic>>> streamLastPresence() async* {
    String uid = auth.currentUser!.uid;

    yield* firestore
        .collection("pegawai")
        .doc(uid)
        .collection("presence")
        .orderBy("date", descending: true)
        .limitToLast(5)
        .snapshots();
  }

  // Stream to get today's presence record for the user
  Stream<DocumentSnapshot<Map<String, dynamic>>> streamTodayPresence() async* {
    String uid = auth.currentUser!.uid;

    String todayID =
        DateFormat.yMd().format(DateTime.now()).replaceAll("/", "-");

    yield* firestore
        .collection("pegawai")
        .doc(uid)
        .collection("presence")
        .doc(todayID)
        .snapshots();
  }
}
