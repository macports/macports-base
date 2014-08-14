<?xml version='1.0' ?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">

<xsl:import href="http://docbook.sourceforge.net/release/xsl/current/manpages/docbook.xsl"/>

<xsl:param name="man.endnotes.list.heading">External References</xsl:param>
<xsl:param name="man.authors.section.enabled">0</xsl:param>
<xsl:param name="man.copyright.section.enabled">0</xsl:param>

<!-- Do not write soelim files -->
<xsl:template name="write.stubs">
</xsl:template>

<!-- Remove top comment with build date -->
<xsl:template name="top.comment">
</xsl:template>

</xsl:stylesheet>
