// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, unused_local_variable, prefer_is_empty, unused_import

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:convex_bottom_bar/convex_bottom_bar.dart';
import 'package:fineer/app/controllers/page_index_controller.dart';
import 'package:fineer/app/modules/overtime/controllers/overtime_controller.dart';
import 'package:fineer/app/routes/app_pages.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../controllers/home_controller.dart';

FirebaseAuth auth = FirebaseAuth.instance;

class HomeView extends GetView<HomeController> {
  final pageC = Get.find<PageIndexController>();

  HomeView({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.blue,
          actions: [
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: controller.streamUser(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return SizedBox();
                  }
                  var role = snapshot.data!.data()!["role"];
                  if (role == "admin") {
                    //admin page
                    return IconButton(
                        onPressed: () => Get.toNamed(Routes.ADD_PEGAWAI),
                        icon: Icon(
                          Icons.add_chart,
                          size: 36,
                        ));
                  } else {
                    return SizedBox();
                  }
                })
          ]),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: controller.streamUser(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(),
              );
            }
            if (snapshot.hasData) {
              Map<String, dynamic> user = snapshot.data!.data()!;

              //Home UI Begin
              return ListView(
                padding: EdgeInsets.symmetric(horizontal: 20),
                children: [
                  // Hero Section - Welcome Screen
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome',
                              style: TextStyle(
                                  fontWeight: FontWeight.normal,
                                  fontSize: 16,
                                  color: Colors.amber),
                            ),
                            SizedBox(
                              height: 6,
                            ),
                            Text(
                              '${user['name']}',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                  fontSize: 24),
                            )
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          await auth.signOut();
                          Get.offAllNamed(Routes.LOGIN);
                        },
                        style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(36)),
                            backgroundColor: Colors.red,
                            elevation: 0),
                        child: Text('Sign Out'),
                      )
                    ],
                  ),
                  //Hero Section End
                  SizedBox(
                    height: 30,
                  ),
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment(0.7, 1),
                          colors: <Color>[
                            Color.fromARGB(255, 55, 130, 236),
                            Color.fromARGB(255, 32, 105, 179),
                            Color.fromARGB(255, 20, 71, 143),
                          ], // Gradient from,
                        )),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${user['job']}',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.white70),
                        ),
                        SizedBox(
                          height: 16,
                        ),
                        Text(
                          '${user['site']}',
                          style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 12,
                  ),
                  // Waktu Absen
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.amber[400]),
                    child: StreamBuilder<
                            DocumentSnapshot<Map<String, dynamic>>>(
                        stream: controller.streamTodayPresence(),
                        builder: (context, snapToday) {
                          if (snapToday.connectionState ==
                              ConnectionState.waiting) {
                            return Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          Map<String, dynamic>? dataToday =
                              snapToday.data?.data();
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Column(
                                children: [
                                  Text(
                                    'Masuk',
                                  ),
                                  Text(
                                    dataToday?["masuk"] == null
                                        ? "--:--"
                                        : DateFormat.Hm().format(DateTime.parse(
                                            dataToday!["masuk"]["date"])),
                                    style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold),
                                  )
                                ],
                              ),
                              Container(
                                width: 2,
                                height: 40,
                                color: Colors.amber[200],
                              ),
                              Column(
                                children: [
                                  Text('Keluar'),
                                  Text(
                                      dataToday?["keluar"] == null
                                          ? "--:--"
                                          : DateFormat.Hm().format(
                                              DateTime.parse(
                                                  dataToday!["keluar"]
                                                      ["date"])),
                                      style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold))
                                ],
                              ),
                            ],
                          );
                        }),
                  ),
                  //Waktu Absen End
                  SizedBox(
                    height: 20,
                  ),

                  //Presence History
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Last 5 Days',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextButton(
                          onPressed: () => Get.toNamed(Routes.ALL_PRESENSI),
                          child: Text(
                            'See More',
                          ))
                    ],
                  ),
                  SizedBox(
                    height: 10,
                  ),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: controller.streamLastPresence(),
                      builder: (context, snapPresence) {
                        if (snapPresence.connectionState ==
                            ConnectionState.waiting) {
                          return Center(child: CircularProgressIndicator());
                        }
                        if (snapPresence.data?.docs.length == 0 ||
                            snapPresence.data == null) {
                          return SizedBox(
                            height: 200,
                            child: Center(
                              child: Text("Belum ada riwayat presensi"),
                            ),
                          );
                        }
                        return ListView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          itemCount: snapPresence.data?.docs.length,
                          itemBuilder: (context, index) {
                            Map<String, dynamic> data =
                                snapPresence.data!.docs[index].data();

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Material(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(12),
                                child: InkWell(
                                  onTap: () => Get.toNamed(
                                    Routes.DETAIL_PRESENSI,
                                    arguments: data,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: EdgeInsets.all(20),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [],
                                        ),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Masuk',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold),
                                            ),
                                            Text(
                                              DateFormat.yMMMEd().format(
                                                  DateTime.parse(data["date"])),
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blue[800],
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(data["masuk"]?["date"] == null
                                            ? "-"
                                            : DateFormat.Hms().format(
                                                DateTime.parse(
                                                    data["masuk"]!["date"]))),
                                        SizedBox(
                                          height: 10,
                                        ),
                                        Text(
                                          'Keluar',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold),
                                        ),
                                        Text(data["keluar"]?["date"] == null
                                            ? "-"
                                            : DateFormat.Hms().format(
                                                DateTime.parse(
                                                    data["keluar"]!["date"]))),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      }),
                ],
              );
            } else {
              return Center(
                child: Text('Tidak Dapat memuat Database User'),
              );
            }
          }),
      //Bottom Nav Bar
      bottomNavigationBar: ConvexAppBar(
        activeColor: Colors.blue,
        top: -30,
        color: Colors.blue[200],
        curveSize: 0,
        style: TabStyle.fixedCircle,
        backgroundColor: Colors.white,
        elevation: 0,
        height: 65,
        items: const [
          TabItem(icon: Icons.home, title: 'Home'),
          TabItem(icon: Icons.fingerprint, title: 'Fingerprint'),
          TabItem(icon: Icons.access_time, title: 'Overtime')
        ],
        initialActiveIndex: pageC.pageIndex.value,
        onTap: (int i) => pageC.changePage(i),
      ),
    );
  }
}
