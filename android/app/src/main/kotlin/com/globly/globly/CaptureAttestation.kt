package com.globly.globly

import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.spec.ECGenParameterSpec

/** Hardware key attestation of a capture; verified by the API (Posts/AndroidAttestation.cs). */
object CaptureAttestation {
    private const val ALIAS = "globly_capture_attestation"

    /** DER certificate chain, leaf first. */
    @Synchronized
    fun attest(challenge: ByteArray): List<ByteArray> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) throw IllegalStateException("Key attestation needs Android 7")
        val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        try {
            val spec = KeyGenParameterSpec.Builder(ALIAS, KeyProperties.PURPOSE_SIGN)
                .setAlgorithmParameterSpec(ECGenParameterSpec("secp256r1"))
                .setDigests(KeyProperties.DIGEST_SHA256)
                .setAttestationChallenge(challenge)
                .apply {
                    // No device ids: not needed.
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) setDevicePropertiesAttestationIncluded(false)
                }
                .build()
            KeyPairGenerator.getInstance(KeyProperties.KEY_ALGORITHM_EC, "AndroidKeyStore").run {
                initialize(spec)
                generateKeyPair()
            }
            val chain = keyStore.getCertificateChain(ALIAS) ?: error("No attestation chain")
            return chain.map { it.encoded }
        } finally {
            // Only the certificate matters.
            runCatching { keyStore.deleteEntry(ALIAS) }
        }
    }
}
