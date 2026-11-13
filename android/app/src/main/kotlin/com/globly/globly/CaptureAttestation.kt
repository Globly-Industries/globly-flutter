package com.globly.globly

import android.os.Build
import android.security.KeyStoreException
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
        return try {
            generate(challenge)
        } catch (e: Exception) {
            // Newer phones may still be fetching attestation keys; one retry helps.
            if (!isTransient(e)) throw IllegalStateException(describe(e), e)
            Thread.sleep(1500)
            try {
                generate(challenge)
            } catch (e2: Exception) {
                throw IllegalStateException(describe(e2), e2)
            }
        }
    }

    private fun generate(challenge: ByteArray): List<ByteArray> {
        val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        try {
            val spec = KeyGenParameterSpec.Builder(ALIAS, KeyProperties.PURPOSE_SIGN)
                .setAlgorithmParameterSpec(ECGenParameterSpec("secp256r1"))
                .setDigests(KeyProperties.DIGEST_SHA256)
                .setAttestationChallenge(challenge)
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

    private fun causes(e: Throwable) = generateSequence(e) { it.cause }.take(6)

    private fun isTransient(e: Throwable) = Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
        causes(e).any { it is KeyStoreException && it.isTransientFailure }

    /** The whole cause chain, since the top message is just "Failed to generate key pair". */
    private fun describe(e: Throwable) = causes(e).joinToString(" <- ") {
        val code = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU && it is KeyStoreException)
            " [code ${it.numericErrorCode}]" else ""
        "${it.javaClass.simpleName}: ${it.message}$code"
    } + " (Android ${Build.VERSION.SDK_INT}, ${Build.MANUFACTURER} ${Build.MODEL})"
}
