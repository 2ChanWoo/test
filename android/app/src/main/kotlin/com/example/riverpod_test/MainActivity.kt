package com.example.riverpod_test

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import no.nordicsemi.android.dfu.DfuServiceInitiator
import no.nordicsemi.android.dfu.DfuServiceListenerHelper
import no.nordicsemi.android.dfu.DfuProgressListenerAdapter

class MainActivity: FlutterActivity() {
    private val METHOD_CHANNEL_NAME = "com.example.riverpod_test/dfu_method"
    private val EVENT_CHANNEL_NAME = "com.example.riverpod_test/dfu_event"

    private var eventSink: EventChannel.EventSink? = null

    private val dfuProgressListener = object : DfuProgressListenerAdapter() {
        override fun onDfuProcessStarting(deviceAddress: String) {
            sendEvent("dfu_process_starting", mapOf("deviceAddress" to deviceAddress))
        }

        override fun onProgressChanged(
            deviceAddress: String,
            percent: Int,
            speed: Float,
            avgSpeed: Float,
            currentPart: Int,
            partsTotal: Int
        ) {
            sendEvent("progress_changed", mapOf(
                "deviceAddress" to deviceAddress,
                "percent" to percent,
                "speed" to speed,
                "avgSpeed" to avgSpeed,
                "currentPart" to currentPart,
                "partsTotal" to partsTotal
            ))
        }

        override fun onDfuCompleted(deviceAddress: String) {
            sendEvent("dfu_completed", mapOf("deviceAddress" to deviceAddress))
        }

        override fun onDfuAborted(deviceAddress: String) {
            sendEvent("dfu_aborted", mapOf("deviceAddress" to deviceAddress))
        }

        override fun onError(
            deviceAddress: String,
            error: Int,
            errorType: Int,
            message: String
        ) {
            sendEvent("on_error", mapOf(
                "deviceAddress" to deviceAddress,
                "error" to error,
                "errorType" to errorType,
                "message" to message
            ))
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        DfuServiceListenerHelper.registerProgressListener(this, dfuProgressListener)

        // Event Channel 설정
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL_NAME).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            }
        )

        // Method Channel 설정
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL_NAME).setMethodCallHandler { call, result ->
            when (call.method) {
                "startDfu" -> {
                    val address = call.argument<String>("address")
                    val filePath = call.argument<String>("filePath")
                    if (address != null && filePath != null) {
                        startDfu(address, filePath)
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGUMENTS", "Address or filePath is null.", null)
                    }
                }
                "abortDfu" -> {
                    val address = call.argument<String>("address")
                    if (address != null) {
                        abortDfu(address)
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGUMENTS", "Address is null.", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun startDfu(address: String, filePath: String) {
        val initiator = DfuServiceInitiator(address)
            .setDeviceName("DfuTarg") // DFU 타겟 디바이스 이름
            .setKeepBond(true) // 본딩 정보 유지
            .setForceDfu(false)
            .setPacketsReceiptNotificationsEnabled(true) // 패킷 수신 알림 활성화
            .setUnsafeExperimentalButtonlessServiceInSecureDfuEnabled(true)


        initiator.setZip(filePath)
        initiator.start(this, DfuService::class.java)
    }

    private fun abortDfu(address: String) {
        val controller = DfuServiceInitiator.getController(address)
        controller?.abort()
    }

    private fun sendEvent(eventName: String, data: Map<String, Any>) {
        val event = mapOf("eventName" to eventName, "data" to data)
        runOnUiThread {
            eventSink?.success(event)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        DfuServiceListenerHelper.unregisterProgressListener(this, dfuProgressListener)
    }
}