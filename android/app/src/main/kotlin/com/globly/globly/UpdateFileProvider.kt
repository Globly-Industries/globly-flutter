package com.globly.globly

import androidx.core.content.FileProvider

/** Own subclass so the manifest entry can't clash with plugins that also declare a FileProvider. */
class UpdateFileProvider : FileProvider()
