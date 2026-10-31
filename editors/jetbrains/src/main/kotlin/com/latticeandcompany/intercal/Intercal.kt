package com.latticeandcompany.intercal

import com.intellij.icons.AllIcons
import com.intellij.lang.Language
import com.intellij.openapi.fileTypes.LanguageFileType
import com.intellij.openapi.vfs.VirtualFile
import javax.swing.Icon

object IntercalLanguage : Language("INTERCAL") {
    @Suppress("unused")
    private fun readResolve(): Any = IntercalLanguage

    override fun getDisplayName(): String = "INTERCAL"
}

object IntercalFileType : LanguageFileType(IntercalLanguage) {
    override fun getName(): String = "INTERCAL"

    override fun getDescription(): String = "INTERCAL, EXTRACAL or INTERCAL on Interstates"

    override fun getDefaultExtension(): String = "i"

    override fun getIcon(): Icon = AllIcons.FileTypes.Text
}

val VirtualFile.isIntercal: Boolean
    get() = fileType == IntercalFileType

val VirtualFile.isInterstates: Boolean
    get() = extension?.lowercase() in setOf("ioi", "2ioi")
