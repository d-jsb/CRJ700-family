<?xml version="1.0" encoding="UTF-8" ?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

<xsl:template match="/">
<html>
	<head>
		<title>Checklist <xsl:value-of select="PropertyList/title" /></title>
	</head>
	<body>
		<xsl:apply-templates select="PropertyList/title" />

		<table border="2">
			<tr>
				<th>Item</th>
				<th>Value</th>
			</tr>
			<xsl:apply-templates select="PropertyList/page" />
		</table>
	</body>
</html>
</xsl:template>

<xsl:template match="title">
	<h1>Checklist "<xsl:value-of select="." />"</h1>
</xsl:template>

<xsl:template match="page">
			<xsl:apply-templates select="item" />
</xsl:template>

<xsl:template match="item">
	<tr>
	<td><xsl:apply-templates select="name" /></td>
	<td><xsl:apply-templates select="value" /></td>
	</tr>
</xsl:template>

<xsl:template match="name">
	<xsl:value-of select="." />
</xsl:template>

<xsl:template match="value">
	<xsl:value-of select="." /><br/>
</xsl:template>

</xsl:stylesheet>