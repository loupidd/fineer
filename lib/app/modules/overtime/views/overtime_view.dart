import 'package:fineer/app/controllers/page_index_controller.dart';
import 'package:flutter/material.dart';

import 'package:get/get.dart';

import '../controllers/overtime_controller.dart';
import 'package:convex_bottom_bar/convex_bottom_bar.dart';

class OvertimeView extends GetView<OvertimeController> {
  final pageC = Get.find<PageIndexController>();
  OvertimeView({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            "Form Pengajuan Lembur",
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 24,
                color: Colors.blueAccent),
          ),
          const SizedBox(
            height: 20,
          ),
          TextField(
            controller: controller.nameC,
            decoration: const InputDecoration(
                border: OutlineInputBorder(), labelText: "Nama"),
          ),
          const SizedBox(
            height: 20,
          ),
          TextField(
            controller: controller.tanggalC,
            decoration: const InputDecoration(
                border: OutlineInputBorder(), labelText: "Tanggal"),
          ),
          const SizedBox(
            height: 20,
          ),
          TextField(
            controller: controller.waktuC,
            decoration: const InputDecoration(
                border: OutlineInputBorder(), labelText: "Waktu"),
          ),
          const SizedBox(
            height: 20,
          ),
          TextField(
            controller: controller.desC,
            decoration: const InputDecoration(
                border: OutlineInputBorder(), labelText: "Deskripsi Pekerjaan"),
          ),
          const SizedBox(
            height: 30,
          ),
          ElevatedButton(
              onPressed: () {
                controller.prosesAddLembur();
              },
              child: const Text("Submit"))
        ],
      ),

      //Backend

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
