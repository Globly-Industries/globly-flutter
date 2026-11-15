package com.globly.globly

import android.os.Build
import android.security.KeyStoreException
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.spec.ECGenParameterSpec
import java.security.spec.RSAKeyGenParameterSpec

/** Hardware key attestation of a capture; verified by the API (Posts/AndroidAttestation.cs). */
object CaptureAttestation {
    private const val ALIAS = "globly_capture_attestation"

    /** DER certificate chain, leaf first. */
    @Synchronized
    fun attest(challenge: ByteArray): List<ByteArray> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) throw IllegalStateException("Key attestation needs Android 7")
        return try {
            withRetry { generate(challenge, rsa = false) }
        } catch (ec: Throwable) {
            // Some vendor TEEs fail EC attestation with their own error codes but can still attest RSA keys.
            try {
                withRetry { generate(challenge, rsa = true) }
            } catch (rsa: Throwable) {
                // Device first: the app truncates this to 1000 chars for the server log.
                throw IllegalStateException("$device EC: ${describe(ec)} | RSA: ${describe(rsa)}", rsa)
            }
        }
    }

    private fun withRetry(block: () -> List<ByteArray>): List<ByteArray> = try {
        block()
    } catch (e: Exception) {
        // Newer phones may still be fetching attestation keys; one retry helps.
        if (!isTransient(e)) throw e
        Thread.sleep(1500)
        block()
    }

    private fun generate(challenge: ByteArray, rsa: Boolean): List<ByteArray> {
        val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        try {
            val builder = KeyGenParameterSpec.Builder(ALIAS, KeyProperties.PURPOSE_SIGN)
                .setDigests(KeyProperties.DIGEST_SHA256)
                .setAttestationChallenge(challenge)
            if (rsa) {
                builder.setAlgorithmParameterSpec(RSAKeyGenParameterSpec(2048, RSAKeyGenParameterSpec.F4))
                    .setSignaturePaddings(KeyProperties.SIGNATURE_PADDING_RSA_PKCS1)
            } else {
                builder.setAlgorithmParameterSpec(ECGenParameterSpec("secp256r1"))
            }
            val algorithm = if (rsa) KeyProperties.KEY_ALGORITHM_RSA else KeyProperties.KEY_ALGORITHM_EC
            KeyPairGenerator.getInstance(algorithm, "AndroidKeyStore").run {
                initialize(builder.build())
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

    private val device get() = "(Android ${Build.VERSION.SDK_INT}, ${Build.MANUFACTURER} ${Build.MODEL})"

    // Keystore2 dumps every key parameter into its message; that alone used up the whole log line.
    // Android's ICU regex rejects an unescaped '}', which broke this object's static init.
    private val keyParams by lazy { Regex("""\s*(and params: )?\[KeyParameter \{.*?\}\s*\]""") }

    /** The whole cause chain on one line, since the top message is just "Failed to generate key pair". */
    private fun describe(e: Throwable) = causes(e).joinToString(" <- ") {
        val code = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU && it is KeyStoreException)
            " [code ${it.numericErrorCode}]" else ""
        // Trimming is cosmetic; it must never mask the real error.
        val message = try {
            it.message?.replace(Regex("\\s+"), " ")?.replace(keyParams, "")
        } catch (_: Throwable) {
            it.message
        }
        "${it.javaClass.simpleName}: $message$code"
    }.take(400)
}
