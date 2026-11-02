package dev.orchestration.agent_orchestration

import android.content.Context
import android.net.wifi.WifiManager
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity

private const val DISCOVERY_LOCK_TAG = "agents-orchestration-discovery"

class MainActivity : FlutterFragmentActivity() {
    private var multicastLock: WifiManager.MulticastLock? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val wifiManager = applicationContext
            .getSystemService(Context.WIFI_SERVICE) as WifiManager
        val discoveryLock = wifiManager.createMulticastLock(DISCOVERY_LOCK_TAG)
        discoveryLock.setReferenceCounted(false)
        discoveryLock.acquire()
        multicastLock = discoveryLock
    }

    override fun onDestroy() {
        multicastLock?.release()
        multicastLock = null
        super.onDestroy()
    }
}
