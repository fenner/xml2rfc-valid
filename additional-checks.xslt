<?xml version="1.0"?>
<!--

  This file contains additional validation checks, beyond
  what xmllint can check.

-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
xmlns:saxon="http://icl.com/saxon" extension-element-prefixes="saxon"
version="1.0">

  <xsl:output method="text" />


<!-- parameter settings copied from Julian -->

<!-- use symbolic reference names instead of numeric ones if a processing instruction <?rfc?>
     exists with contents symrefs="yes". Can be overriden by an XSLT parameter -->

<xsl:param name="xml2rfc-symrefs"
  select="substring-after(
      translate(/processing-instruction('rfc')[contains(.,'symrefs=')], concat($quote-chars,' '), ''),
        'symrefs=')"
/>

<!-- sort references if a processing instruction <?rfc?>
     exists with contents sortrefs="yes". Can be overriden by an XSLT parameter -->

<xsl:param name="xml2rfc-sortrefs"
  select="substring-after(
      translate(/processing-instruction('rfc')[contains(.,'sortrefs=')], concat($quote-chars,' '), ''),
        'sortrefs=')"
/>

<!-- make it a private paper -->

<xsl:param name="xml2rfc-private"
  select="substring-after(
      translate(/processing-instruction('rfc')[contains(.,'private=')], concat($quote-chars,' '), ''),
        'private=')"
/>

<!-- strict error reporting -->

<xsl:param name="xml2rfc-strict"
  select="substring-after(
      translate(/processing-instruction('rfc')[contains(.,'strict=')], concat($quote-chars,' '), ''),
        'strict=')"
/>

<xsl:param name="strictlevel">
  <xsl:choose>
    <xsl:when test="$xml2rfc-strict = 'yes'">
      <xsl:text>error</xsl:text>
    </xsl:when>
    <xsl:otherwise>
      <xsl:text>fyi</xsl:text>
    </xsl:otherwise>
  </xsl:choose>
</xsl:param>

<!-- delimiters in PIs -->
<xsl:variable name="quote-chars">"'</xsl:variable>     


  <xsl:template match="reference">
    <xsl:if test="not(@anchor) and ($xml2rfc-symrefs = 'yes' or $xml2rfc-sortrefs = 'yes')">
      <xsl:call-template name="msg">
	<xsl:with-param name="msg">When using symrefs="yes" or sortrefs="yes" all references require anchors and the reference with title "<xsl:value-of select="normalize-space(front/title)"/>" doesn't have one</xsl:with-param>
      </xsl:call-template>
    </xsl:if>
    <!-- this element might contain others that need to be checked -->
    <xsl:apply-templates/>
  </xsl:template>

  <xsl:template match="t/figure">
    <xsl:call-template name="msg">
      <xsl:with-param name="msg">&lt;figure&gt; inside &lt;t&gt; is deprecated by rfc2629bis</xsl:with-param>
    </xsl:call-template>
    <!-- this element might contain others that need to be checked -->
    <xsl:apply-templates/>
  </xsl:template>

  <xsl:template match="/rfc/front">
    <xsl:if test="count(/rfc/front/author) > 5">
      <xsl:call-template name="msg">
	<xsl:with-param name="type">
	  <xsl:value-of select="$strictlevel"/>
	</xsl:with-param>
	<xsl:with-param name="msg">The RFC Editor prefers &lt; 5 authors</xsl:with-param>
      </xsl:call-template>
    </xsl:if>
    <xsl:if test="not(./abstract)">
      <xsl:call-template name="msg">
	<xsl:with-param name="type">
	  <xsl:value-of select="$strictlevel"/>
	</xsl:with-param>
	<xsl:with-param name="msg">No Abstract</xsl:with-param>
      </xsl:call-template>
    </xsl:if>
    <!-- this element might contain others that need to be checked -->
    <xsl:apply-templates/>
  </xsl:template>

  <xsl:template match="/rfc/front/title">
    <xsl:if test="string-length(.) > 39 and not(@abbrev)">
      <xsl:call-template name="msg">
	<xsl:with-param name="msg">title of <xsl:value-of select="string-length(.)"/> chars requires abbrev= element</xsl:with-param>
      </xsl:call-template>
    </xsl:if>
    <xsl:if test="string-length(@abbrev) > 39">
      <xsl:call-template name="msg">
	<xsl:with-param name="msg">title abbreviation of <xsl:value-of select="string-length(@abbrev)"/> chars is too long</xsl:with-param>
      </xsl:call-template>
    </xsl:if>
  </xsl:template>

  <xsl:template match="/rfc/front/abstract//*[eref or xref]">
    <xsl:if test="not($xml2rfc-private)">
      <xsl:call-template name="msg">
	<xsl:with-param name="type">
	  <xsl:value-of select="$strictlevel"/>
	</xsl:with-param>
	<xsl:with-param name="msg">The RFC Editor does not permit references in the abstract</xsl:with-param>
      </xsl:call-template>
    </xsl:if>
  </xsl:template>

  <xsl:template match="//*[@anchor]">
    <xsl:if test="not(//xref[@target=current()/@anchor]) and not(/rfc[@iprExtract=current()/@anchor])">
      <xsl:call-template name="msg">
	<xsl:with-param name="msg">anchor <xsl:value-of select="@anchor"/> not referenced</xsl:with-param>
	<xsl:with-param name="type">
	  <xsl:choose>
	    <xsl:when test="local-name(.) = 'reference'">warning</xsl:when>
	    <xsl:otherwise>fyi</xsl:otherwise>
	  </xsl:choose>
	</xsl:with-param>
      </xsl:call-template>
    </xsl:if>
    <xsl:if test="//text()[contains(., concat('[', current()/@anchor, ']'))]">
      <xsl:call-template name="msg">
	<xsl:with-param name="msg">anchor <xsl:value-of select="@anchor"/> referred to in plain text as [<xsl:value-of select="@anchor"/>]</xsl:with-param>
	<xsl:with-param name="type">fyi</xsl:with-param>
      </xsl:call-template>
    </xsl:if>
    <xsl:if test="count(//*[@anchor=current()/@anchor]) > 1">
      <xsl:call-template name="msg">
	<xsl:with-param name="msg">anchor <xsl:value-of select="@anchor"/> used multiple times</xsl:with-param>
      </xsl:call-template>
    </xsl:if>
    <!-- this element might contain others that need to be checked -->
    <xsl:apply-templates/>
  </xsl:template>

  <!--
	although the order of the city, region, code, and country
	elements isn't specified, at most one of each may be present
    -->
  <xsl:template match="postal">
    <xsl:if test="count(city) > 1">
      <xsl:call-template name="msg">
	<xsl:with-param name="msg">at most one &lt;city&gt; may be present</xsl:with-param>
      </xsl:call-template>
    </xsl:if>
    <xsl:if test="count(region) > 1">
      <xsl:call-template name="msg">
	<xsl:with-param name="msg">at most one &lt;region&gt; may be present</xsl:with-param>
      </xsl:call-template>
    </xsl:if>
    <xsl:if test="count(code) > 1">
      <xsl:call-template name="msg">
	<xsl:with-param name="msg">at most one &lt;code&gt; may be present</xsl:with-param>
      </xsl:call-template>
    </xsl:if>
    <xsl:if test="count(country) > 1">
      <xsl:call-template name="msg">
	<xsl:with-param name="msg">at most one &lt;country&gt; may be present</xsl:with-param>
      </xsl:call-template>
    </xsl:if>
  </xsl:template>

  <xsl:template match="seriesInfo">
    <xsl:if test="./@name = 'Internet Draft' or ./@name = 'I-D' or ./@name = 'internet draft' or ./@name = 'i-d'">
      <xsl:call-template name="msg">
	<xsl:with-param name="msg">series name should be Internet-Draft</xsl:with-param>
	<xsl:with-param name="type">warning</xsl:with-param>
      </xsl:call-template>
    </xsl:if>
    <!-- check document status if we're using Bill's special includes -->
    <!-- I'd rather have these tests in the <reference> template,
	 but I can't figure out how to match seriesInfo in there -
	 these same ifs with seriesInfo[@name='...'] don't work.
	 (They do work in xmllint - -shell's xpath function, so
	  I'm stumped.)  -->
    <xsl:if test="@name='I-D Status' and @value='expired'">
      <xsl:call-template name="msg">
	<xsl:with-param name="msg">The I-D <xsl:value-of select="../seriesInfo[@name='Internet-Draft']/@value"/> is expired</xsl:with-param>
	<xsl:with-param name="type">warning</xsl:with-param>
      </xsl:call-template>
    </xsl:if>
    <xsl:if test="@name='I-D Status' and @value='withdrawn'">
      <xsl:call-template name="msg">
	<xsl:with-param name="msg">The I-D <xsl:value-of select="../seriesInfo[@name='Internet-Draft']/@value"/> has been withdrawn</xsl:with-param>
	<xsl:with-param name="type">warning</xsl:with-param>
      </xsl:call-template>
    </xsl:if>
    <xsl:if test="@name='Replaced By'">
      <xsl:call-template name="msg">
	<xsl:with-param name="msg">The I-D <xsl:value-of select="../seriesInfo[@name='Internet-Draft']/@value"/> has been replaced by <xsl:value-of select="@value"/></xsl:with-param>
	<xsl:with-param name="type">warning</xsl:with-param>
      </xsl:call-template>
    </xsl:if>
    <xsl:if test="@name='Obsoleted by'">
      <xsl:call-template name="msg">
	<xsl:with-param name="msg">RFC <xsl:value-of select="../seriesInfo[@name='RFC']/@value"/> has been obsoleted by <xsl:value-of select="@value"/></xsl:with-param>
	<xsl:with-param name="type">warning</xsl:with-param>
      </xsl:call-template>
    </xsl:if>
  </xsl:template>

  <!--
    Check RFC attributes:
    - historic doesn't have series number
    - iprExtract only makes sense with restrictive IPR
    - non-private documents need either ipr or number
    -->
  <xsl:template match="rfc">
    <xsl:if test="./@category = 'historic' and ./@seriesNo">
      <xsl:call-template name="msg">
	<xsl:with-param name="msg">historic documents should not have a seriesNo</xsl:with-param>
      </xsl:call-template>
    </xsl:if>
    <xsl:if test="./@iprExtract and not(./@ipr = 'noDerivatives3667' or ./ipr = 'noModification3667' or ./@ipr = 'noDerivatives3978' or ./@ipr = 'noModifications3978')">
      <xsl:call-template name="msg">
	<xsl:with-param name="msg">iprExtract is meaningless without restrictive ipr such as noDerivatives3978 or noModifications3978</xsl:with-param>
	<xsl:with-param name="type">warning</xsl:with-param>
      </xsl:call-template>
    </xsl:if>
    <xsl:if test="not($xml2rfc-private) and (not(./@ipr) and not(./@number))">
      <xsl:call-template name="msg">
	<xsl:with-param name="msg">&lt;rfc&gt; element requires either ipr (for an I-D) or number (for RFC) attribute</xsl:with-param>
      </xsl:call-template>
    </xsl:if>
    <xsl:if test="not(@number) and not(contains(@ipr, '3978'))">
      <xsl:call-template name="msg">
	<xsl:with-param name="msg">3978-style IPR is required beginning 6 May 2005 (you are using <xsl:value-of select="@ipr"/>)</xsl:with-param>
      </xsl:call-template>
    </xsl:if>
    <xsl:apply-templates/>
  </xsl:template>

  
  <xsl:template match="text()|@*"/>

<!--
possible additional checks:
check list style=

STRICT checks:
X too many authors
X reference in abstract
X missing abstract
_ missing security considerations
_ no TOC but document long
_ img src requires alt
_ output line > 72 characters
_ entity problem
-->

  <!-- note on line numbers: in entity inclusions, the line number
     - appears to be that of the included file.  Is there a way to
     - see which document we're in?
     -->
  <xsl:template name="msg">
    <xsl:param name="msg"/>
    <xsl:param name="type">error</xsl:param>
    <xsl:variable name="lineinfo">
      <xsl:if test="function-available('saxon:line-number')">
	<xsl:value-of select="saxon:line-number()"/><xsl:text>: </xsl:text>
      </xsl:if>
    </xsl:variable>
    <xsl:message><xsl:value-of select="$lineinfo"/><xsl:value-of select="$type"/>: <xsl:value-of select="$msg"/></xsl:message>
  </xsl:template>


</xsl:stylesheet>
