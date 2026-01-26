import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

class PaymentService {
  // ⚠️ NEVER store Secret Keys here in production. Use a backend URL.
  // For testing M-Pesa, you can use the sandbox keys temporarily.
  
  static const String mpesaBaseUrl = "https://sandbox.safaricom.co.mp/mpesa/stkpush/v1/processrequest";
  static const String stripeBaseUrl = "https://api.stripe.com/v1";

  // --- 1. M-PESA STK PUSH (Kenya) ---
  static Future<void> initiateMpesaPayment({
    required String phoneNumber, 
    required double amount
  }) async {
    try {
      // 1. Get Access Token (Auth) - You usually hit your OWN server here
      String accessToken = await _getMpesaAccessToken(); 

      // 2. Trigger STK Push
      final response = await http.post(
        Uri.parse(mpesaBaseUrl),
        headers: {
          "Authorization": "Bearer $accessToken",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "BusinessShortCode": "174379", // Sandbox Paybill
          "Password": "...", // Generated Base64 Password
          "Timestamp": "20240126120000",
          "TransactionType": "CustomerPayBillOnline",
          "Amount": amount.toInt(),
          "PartyA": phoneNumber, // User Phone
          "PartyB": "174379",
          "PhoneNumber": phoneNumber,
          "CallBackURL": "https://your-backend.com/callback",
          "AccountReference": "SDA Ministry",
          "TransactionDesc": "Donation"
        }),
      );

      if (response.statusCode == 200) {
        debugPrint("M-Pesa Prompt Sent!");
      } else {
        throw "M-Pesa Error: ${response.body}";
      }
    } catch (e) {
      debugPrint("Payment Error: $e");
      rethrow; // Pass error to UI
    }
  }

  // --- 2. STRIPE PAYMENT (International) ---
  static Future<void> makeStripePayment(double amount, String currency) async {
    try {
      // 1. Create Payment Intent on YOUR Server (or directly to Stripe for test)
      // Note: In Prod, fetch 'client_secret' from your backend, NOT directly here.
      final paymentIntent = await _createPaymentIntent(amount, currency);
      
      // 2. Initialize Payment Sheet (using flutter_stripe package)
      /* await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: paymentIntent['client_secret'],
          merchantDisplayName: 'SDA Ministry',
        ),
      );

      // 3. Display Payment Sheet
      await Stripe.instance.presentPaymentSheet();
      */
      debugPrint("Payment Success!");
    } catch (e) {
      debugPrint("Stripe Error: $e");
      rethrow;
    }
  }

  // Mock Helper for Stripe Intent
  static Future<Map<String, dynamic>> _createPaymentIntent(double amount, String currency) async {
    // Call your backend here
    return {'client_secret': 'sk_test_...'}; 
  }

  // Mock Helper for Mpesa Token
  static Future<String> _getMpesaAccessToken() async {
    // Call your backend or Daraja auth API
    return "mock_token";
  }
}