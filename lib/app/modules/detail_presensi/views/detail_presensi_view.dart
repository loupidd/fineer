import 'package:flutter/material.dart';

import 'package:get/get.dart';

import '../controllers/detail_presensi_controller.dart';
import 'package:intl/intl.dart';

class DetailPresensiView extends GetView<DetailPresensiController> {
  DetailPresensiView({super.key});
  final Map<String, dynamic> data = Get.arguments;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.blue,
          title: const Text('Detail Presensi'),
          centerTitle: true,
        ),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey[200]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                    child: Text(
                  DateFormat.yMMMMEEEEd().format(DateTime.parse(data["date"])),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18),
                )),
                const SizedBox(
                  height: 20,
                ),
                //Masuk
                const Text(
                  'Masuk',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                    'Waktu :  ${DateFormat.jms().format(DateTime.parse(data["masuk"]!["date"]))}'),
                Text(
                    'Posisi :  ${data["masuk"]!["lat"]}, ${data["masuk"]!["long"]}'),
                Text('Status : ${data["masuk"]!["status"]}'),
                Text('Address : ${data["masuk"]!["address"]}'),
                const SizedBox(
                  height: 20,
                ),

                //Keluar
                const Text(
                  'Keluar',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(data["keluar"]?["date"] == null
                    ? "-"
                    : 'Waktu :  ${DateFormat.jms().format(DateTime.parse(data["keluar"]!["date"]))}'),
                Text(data["keluar"]?["lat"] == null &&
                        data["keluar"]?["long"] == null
                    ? "Posisi: -"
                    : 'Posisi :  ${data["keluar"]!["lat"]}, ${data["keluar"]!["long"]}'),
                Text(data["keluar"]?["status"] == null
                    ? "Status : -"
                    : 'Status : ${data["keluar"]!["status"]}'),
                Text(data["keluar"]?["address"] == null
                    ? "Address : -"
                    : 'Address : ${data["keluar"]!["address"]}'),
                const SizedBox(
                  height: 20,
                ),
              ],
            ),
          ),
        ]));
  }
}
