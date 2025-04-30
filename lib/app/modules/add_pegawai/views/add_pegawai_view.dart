// ignore_for_file: prefer_const_literals_to_create_immutables, prefer_const_constructors

import 'package:flutter/material.dart';

import 'package:get/get.dart';

import '../controllers/add_pegawai_controller.dart';

class AddPegawaiView extends GetView<AddPegawaiController> {
  const AddPegawaiView({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        foregroundColor: Colors.blue,
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Register'),
        centerTitle: true,
      ),
      //Input Form Starts
      body: ListView(padding: EdgeInsets.all(20), children: [
        TextField(
          controller: controller.nameC,
          decoration:
              InputDecoration(border: OutlineInputBorder(), labelText: 'Nama'),
        ),
        SizedBox(
          height: 20,
        ),
        TextField(
          controller: controller.emailC,
          decoration:
              InputDecoration(border: OutlineInputBorder(), labelText: 'Email'),
        ),
        SizedBox(
          height: 20,
        ),
        TextField(
          controller: controller.nikC,
          decoration:
              InputDecoration(border: OutlineInputBorder(), labelText: 'NIK'),
        ),
        SizedBox(
          height: 30,
        ),
        TextField(
          controller: controller.jobC,
          decoration: InputDecoration(
              border: OutlineInputBorder(), labelText: 'Divisi'),
        ),
        SizedBox(
          height: 30,
        ),
        TextField(
          controller: controller.siteC,
          decoration:
              InputDecoration(border: OutlineInputBorder(), labelText: 'Site'),
        ),
        SizedBox(
          height: 30,
        ),
        ElevatedButton(
            onPressed: () {
              controller.addPegawai();
            },
            child: Text('Register'))
      ]), //Input Form End
    );
  }
}
