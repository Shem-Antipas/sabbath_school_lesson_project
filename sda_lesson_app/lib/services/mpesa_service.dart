import 'package:flutter/material.dart';
import 'package:mpesa_flutter_plugin/mpesa_flutter_plugin.dart';

class MpesaService {
  // ⚠️ SANDBOX CREDENTIALS (REPLACE WITH YOURS FROM DARAJA PORTAL)
  static const String consumerKey = "XpfykHAO4GE2PSdAQqdbG09IxWvADAO34nU6JkYuryDTCinB";
  static const String consumerSecret = "TESt";
  static const String passKey = "TEST"; // Default Sandbox Passkey
  static void initialize() {
    MpesaFlutterPlugin.setConsumerKey(consumerKey);
    MpesaFlutterPlugin.setConsumerSecret(consumerSecret);
  }

  static Future<void> startSTKPush({
    required BuildContext context,
    required String phoneNumber,
    required double amount,
  }) async {
    // 1. Format Phone Number (Must be 2547XXXXXXXX)
    String cleanPhone = phoneNumber.trim();
    if (cleanPhone.startsWith("0")) {
      cleanPhone = "254${cleanPhone.substring(1)}";
    } else if (cleanPhone.startsWith("+")) {
      cleanPhone = cleanPhone.substring(1);
    }

    try {
      // 2. Trigger STK Push using the correct Plugin Method
      dynamic transactionInitialisation = await MpesaFlutterPlugin.initializeMpesaSTKPush(
        businessShortCode: "174379", // Sandbox Paybill
        transactionType: TransactionType.CustomerPayBillOnline,
        amount: amount,
        partyA: cleanPhone,
        partyB: "174379",
        // ⚠️ REQUIRED: Use a valid URL (e.g., from webhook.site) for testing
        callBackURL: Uri.parse("https://webhook.site/2d01f950-92e2-4a03-8650-460c1d3706ac"), 
        accountReference: "SDA Donation",
        phoneNumber: cleanPhone,
        baseUri: Uri.parse("https://sandbox.safaricom.co.ke/"),
        transactionDesc: "Donation to Ministry",
        passKey: passKey,
      );

      // 3. Handle Response
      // Note: This plugin returns the raw JSON response from Safaricom
      print("M-Pesa Result: $transactionInitialisation");

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Request Sent! Check your phone to enter PIN."),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 5),
        ),
      );

    } catch (e) {
      debugPrint("M-Pesa Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Payment Failed. Check your internet or API Keys."), 
          backgroundColor: Colors.red
        ),
      );
    }
  }
}