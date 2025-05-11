// ignore_for_file: unnecessary_overrides, unused_import

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class HomeController extends GetxController {
  RxBool isLoading = false.obs;

  // Value notifier for current time to minimize rebuilds
  final currentTime = ValueNotifier<DateTime>(DateTime.now());

  // Timer for updating time
  late final StreamSubscription<DateTime> timer;

  FirebaseAuth auth = FirebaseAuth.instance;
  FirebaseFirestore firestore = FirebaseFirestore.instance;

  @override
  void onInit() {
    super.onInit();
    // Setup timer to update current time every minute
    timer = Stream.periodic(const Duration(minutes: 1), (_) => DateTime.now())
        .listen((time) => currentTime.value = time);
  }

  @override
  void onClose() {
    // Dispose of timer when controller is closed
    timer.cancel();
    currentTime.dispose();
    super.onClose();
  }

  // Stream to fetch user data from Firestore
  Stream<DocumentSnapshot<Map<String, dynamic>>> streamUser() async* {
    if (auth.currentUser == null) {
      yield* const Stream.empty();
    } else {
      String uid = auth.currentUser!.uid;
      yield* firestore.collection("pegawai").doc(uid).snapshots();
    }
  }

  // Future to fetch user data once for optimized loading
  Future<DocumentSnapshot<Map<String, dynamic>>> getUserOnce() async {
    if (auth.currentUser == null) {
      throw Exception("User not logged in");
    }
    String uid = auth.currentUser!.uid;
    return await firestore.collection("pegawai").doc(uid).get();
  }

  // Stream to get last 5 presence records for the user
  Stream<QuerySnapshot<Map<String, dynamic>>> streamLastPresence() async* {
    String uid = auth.currentUser!.uid;

    yield* firestore
        .collection("pegawai")
        .doc(uid)
        .collection("presence")
        .orderBy("date", descending: true)
        .limit(5)
        .snapshots();
  }

  // Future to get last 5 presence records once for optimized loading
  Future<QuerySnapshot<Map<String, dynamic>>> getLastPresenceOnce() async {
    String uid = auth.currentUser!.uid;

    return await firestore
        .collection("pegawai")
        .doc(uid)
        .collection("presence")
        .orderBy("date", descending: true)
        .limit(5)
        .get();
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

  // Future to get today's presence once for optimized loading
  Future<DocumentSnapshot<Map<String, dynamic>>> getTodayPresenceOnce() async {
    String uid = auth.currentUser!.uid;

    String todayID =
        DateFormat.yMd().format(DateTime.now()).replaceAll("/", "-");

    return await firestore
        .collection("pegawai")
        .doc(uid)
        .collection("presence")
        .doc(todayID)
        .get();
  }
}
