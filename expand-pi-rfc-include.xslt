<?xml version="1.0"?>

<!--
 - Copyright (C) 2004  Internet Systems Consortium, Inc. ("ISC")
 - 
 - Permission to use, copy, modify, and distribute this software for any
 - purpose with or without fee is hereby granted, provided that the above
 - copyright notice and this permission notice appear in all copies.
 - 
 - THE SOFTWARE IS PROVIDED "AS IS" AND ISC DISCLAIMS ALL WARRANTIES WITH
 - REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY
 - AND FITNESS.  IN NO EVENT SHALL ISC BE LIABLE FOR ANY SPECIAL, DIRECT,
 - INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM
 - LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE
 - OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
 - PERFORMANCE OF THIS SOFTWARE.
-->

<!-- $Id: expand-pi-rfc-include.xslt,v 1.4 2005/01/28 21:28:09 fenner Exp $
 -
 - Expand xml2rfc <?rfc include="foo"?> processing instructions.
 -
 - I wrote this for use with xsltproc, although presumably one could
 - use it with another xslt engine without much effort.  When using it
 - with xsltproc, xsltproc's "path" command-line option provides an
 - easy way to provide the same functionality as xml2rfc's XML_LIBRARY
 - environment variable (one can in fact just use the value of
 - XML_LIBRARY as the argument to the path option and the right thing
 - should happen).
 -
 - Input for this stylesheet is an RFC 2629 XML document; output is
 - the same document, still in XML, but with <?rfc include="foo"?> PIs
 - expanded.
-->

<!--
 - Adapted for use with xxe by Bill Fenner, 2004-12-22
-->

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
xmlns:saxon="http://icl.com/saxon" extension-element-prefixes="saxon"
version="1.0">
  <xsl:output indent='yes'/>

  <xsl:template match="processing-instruction('rfc')">
    <xsl:choose>
      <xsl:when test="contains(.,'include=')">
	<xsl:variable name="elide">&#9;&#10;&#13;&#32;&#34;&#39;</xsl:variable>
	<xsl:variable name="href"><xsl:value-of select="
	  translate(substring-after(.,'='), $elide, '')"/><xsl:if test="
          not(contains(.,'.xml'))">.xml</xsl:if>
	</xsl:variable>
        <xsl:comment> Begin inclusion <xsl:value-of select="$href"/>. </xsl:comment>
        <xsl:variable name="include" select="document($href,.)"/>
	<xsl:variable name="lineinfo">
	  <xsl:if test="function-available('saxon:line-number')">
	    <xsl:value-of select="saxon:line-number()"/><xsl:text>: </xsl:text>
	  </xsl:if>
	</xsl:variable>
	<xsl:choose>
	  <xsl:when test="$include">
	    <xsl:copy-of select="$include"/>
	  </xsl:when>
	  <xsl:when test="starts-with($href,'reference.rfc.')">
	    <xsl:message><xsl:value-of select="$lineinfo"/>&lt;?rfc include?&gt; filenames are case sensitive; trying to load reference.RFC.<xsl:value-of select="substring-after($href,'reference.rfc.')"/> instead.</xsl:message>
	    <xsl:copy-of select="document(concat('reference.RFC.', substring-after($href,'reference.rfc.')))"/>
	  </xsl:when>
	  <xsl:otherwise>
	    <xsl:message><xsl:value-of select="$lineinfo"/>(don't know offhand what's wrong with <xsl:value-of select="$href"/>)</xsl:message>
	  </xsl:otherwise>
	</xsl:choose>
        <xsl:comment> End inclusion <xsl:value-of select="$href"/>. </xsl:comment>
      </xsl:when>
      <xsl:otherwise>
        <xsl:copy/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="@*|node()">
    <xsl:copy>
      <xsl:copy-of select="@*"/>
      <xsl:apply-templates/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="/">
    <xsl:apply-templates/>
  </xsl:template>

</xsl:stylesheet>
