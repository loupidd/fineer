// ignore_for_file: prefer_is_empty

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fineer/app/routes/app_pages.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:get/get.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';

import '../controllers/all_presensi_controller.dart';

class AllPresensiView extends GetView<AllPresensiController> {
  const AllPresensiView({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.blue,
        title: const Text('Riwayat Presensi'),
        centerTitle: true,
      ),
      body: GetBuilder<AllPresensiController>(
        builder: (c) => FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
            future: controller.getAllPresence(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }
              if (snap.data?.docs.length == 0 || snap.data == null) {
                return const SizedBox(
                  height: 200,
                  child: Center(
                    child: Text("Belum ada riwayat presensi"),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: snap.data!.docs.length,
                itemBuilder: (context, index) {
                  Map<String, dynamic> data = snap.data!.docs[index].data();

                  //UI Detail
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
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Masuk',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    DateFormat.yMMMEd()
                                        .format(DateTime.parse(data["date"])),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              Text(data["masuk"]?["date"] == null
                                  ? "-"
                                  : DateFormat.Hms().format(
                                      DateTime.parse(data["masuk"]!["date"]))),
                              const SizedBox(
                                height: 10,
                              ),
                              const Text(
                                'Keluar',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(data["keluar"]?["date"] == null
                                  ? "-"
                                  : DateFormat.Hms().format(
                                      DateTime.parse(data["keluar"]!["date"]))),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            }),
      ),

      //Filter Fucntion
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          //syncfusion Datepicker
          Get.dialog(Dialog(
            child: Container(
              padding: const EdgeInsets.all(20),
              height: 400,
              child: SfDateRangePicker(
                monthViewSettings:
                    const DateRangePickerMonthViewSettings(firstDayOfWeek: 1),
                selectionMode: DateRangePickerSelectionMode.range,
                showActionButtons: true,
                onCancel: () => Get.back(),
                onSubmit: (obj) {
                  if (obj != null) {
                    //proses
                    if ((obj as PickerDateRange).endDate != null) {
                      controller.pickDate(obj.startDate!, obj.endDate!);
                    }
                  }
                },
              ),
            ),
          ));
        },
        child: const Icon(Icons.format_list_bulleted),
      ),
    );
  }
}
