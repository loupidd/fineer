import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

class DetailPresensiController extends GetxController {
  final isLoading = true.obs;
  final presenceData = Rxn<Map<String, dynamic>>();
  final errorMessage = Rxn<String>();

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    
    if (args != null) {
      // Check the type of the arguments
      if (args is String) {
        // If it's a string ID, fetch data from Firebase
        fetchPresenceData(args);
      } else if (args is Map<String, dynamic>) {
        // If it's already a map, use it directly
        presenceData.value = args;
        isLoading.value = false;
      } else {
        // Invalid argument type
        errorMessage.value = 'Invalid argument type: ${args.runtimeType}';
        Get.snackbar('Error', 'Invalid argument type');
        isLoading.value = false;
      }
    } else {
      errorMessage.value = 'No arguments provided';
      Get.snackbar('Error', 'No data provided');
      isLoading.value = false;
    }
  }

  Future<void> fetchPresenceData(String id) async {
    try {
      // Check both collection names to ensure we find the data
      DocumentSnapshot<Map<String, dynamic>> doc;
      
      // First try 'presence' collection
      doc = await FirebaseFirestore.instance.collection('presence').doc(id).get();
      
      // If not found, try 'presensi' collection
      if (!doc.exists) {
        doc = await FirebaseFirestore.instance.collection('presensi').doc(id).get();
      }
      
      if (doc.exists && doc.data() != null) {
        presenceData.value = doc.data();
      } else {
        errorMessage.value = 'No presence data found with ID: $id';
        Get.snackbar('Error', 'Presence data not found');
      }
    } catch (e) {
      print('Error fetching presence data: $e');
      errorMessage.value = 'Failed to load presence data: $e';
      Get.snackbar('Error', 'Failed to load presence data');
    } finally {
      isLoading.value = false;
    }
  }
}
