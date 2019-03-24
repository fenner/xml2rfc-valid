#!/usr/bin/perl
#
#
use CGI qw(:standard);
use CGI::Carp qw(fatalsToBrowser);

use Data::Dumper;
use File::Temp qw(tempdir);

#
# If using entity includes, use the catalog so we're not dependent
# on xml.resource.org.
$ENV{"SGML_CATALOG_FILES"} = "/home/fenner/public_html/ietf/xml2rfc-valid/catalog.xml";

$q = new CGI;

$cleanup = $q->param("delete") ? 1 : 0;
$d = tempdir("xml2rfc-valid.cgi.XXXXX", TMPDIR => 1, CLEANUP => $cleanup);
$filename = $q->param("source");
$fh = $q->upload("source");

print header("text/html");
print start_html("Validation results for $filename"),
	h1("Validation results for $filename");

chdir($d) || die "Changing to temp dir $d: $!\n";
open(POSTDATA, ">${d}.txt");	# outside the directory since that gets rm'd
print POSTDATA "... data from web form:\n";
$q->save(POSTDATA);
print POSTDATA "\n... environment:\n";
foreach $e (sort keys %ENV) {
	print POSTDATA "$e=$ENV{$e}\n";
}
close(POSTDATA);

$has_rfcincludes = 0;
open(DRAFT, ">draft.xml") || die "writing draft.xml: $!\n";
{
	local $/;
	$doc = <$fh>;

	# Watch for includes
	$has_rfcincludes = 1 if ($doc =~ /<\?rfc\s+include/);
	# Make sure the DTD reference is relative
	$doc =~ s,http://xml.resource.org/authoring/rfc2629.dtd,rfc2629.dtd,;
	# Turn Parameter Entities into General Entities;
	# you almost definitely don't actually want Parameter Entities.
	if ($doc =~ s,(ENTITY\s+)%\s+,$1,gs) {
		$had_param_entity = 1;
	}
	print DRAFT $doc;
}
close($fh);

print p("Processing...");
symlink("/home/fenner/public_html/ietf/xml2rfc-valid/rfc2629.dtd","rfc2629.dtd") || die "ln -s rfc2629.dtd\n";
symlink("/home/fenner/public_html/ietf/xml2rfc-valid/rfc2629-xhtml.ent","rfc2629-xhtml.ent") || die "ln -s rfc2629-xhtml.ent\n";
symlink("/home/fenner/public_html/ietf/xml2rfc-valid/rfc2629-other.ent","rfc2629-other.ent") || die "ln -s rfc2629-other.ent\n";

#print start_ol;
print "<ol>\n";
if ($had_param_entity) {
	print li("Your document had parameter entities (e.g., &lt;!ENTITY % SYSTEM ...&gt;).  I changed them to general entities (e.g., &lt;!ENTITY SYSTEM ...&gt;) since I don't know any reason to use parameter entities for xml2rfc.  I'd suggest you do the same in your source file.  (If I'm wrong, and you need to use parameter entities, please let Bill know!)");
}
if ($has_rfcincludes) {
	print li("Processing &lt?rfc include=...?> ...");
	rename('draft.xml', 'draft.xml.orig');
	#
	# Expand <?rfc include=?> if present, using Rob's XSL.
	# xsltproc args: --path points to directories to check.
	@includeresult = `/usr/local/bin/xsltproc --path '/home/fenner/public_html/ietf/xml/bibxml:/home/fenner/public_html/ietf/xml/bibxml3' /home/fenner/public_html/ietf/xml2rfc-valid/expand-pi-rfc-include.xslt draft.xml.orig 2>&1 > draft.xml`;
	if (@includeresult) {
		print ul(li([map {htmlify($_)} @includeresult]));
		print li("[errors above may cause errors below]");
	}
}
print li("Validating document...");
#
# XXX to do:
#  if there are entities, save the output of this step
#  and use it in the final step
#  Maybe redo this: 1. expand <?rfc include?>, 2. expand entities and
#   check for well-formed XML; 3. check validity, 4. check additional stuff
#   if #2 fails then stop.
#
# xmllint args:
# --loaddtd: loads the DTD to get entities defined
# --noent: loads entities (brilliant name, eh)
# --noout: don't display the parsed xml
# --dtdvalid: validate against this DTD
# --catalogs: use catalog to enable local fetching of bibxml
@xmllintresult = `/usr/local/bin/xmllint --loaddtd --noent --noout --dtdvalid rfc2629.dtd --catalogs draft.xml 2>&1`;
if ($?) {
	printres(@xmllintresult);
if (0) {	# until we're sure that printres() is the same
	print p("note: <?rfc include?> processing may have shifted line numbers") if ($has_rfcincludes);
	print "<ul>\n";	#XXX
	#
	# read in file - note that the <?rfc include=?> processing
	# may have modified it from what was uploaded
	open(DRAFT, "draft.xml") || die "draft.xml: $!\n";
	@draft = <DRAFT>;
	close(DRAFT);
	foreach $result (@xmllintresult) {
		# generic failure message which can include ID/IDREF mismatch
		# so since we've got our own failure message, skip this one.
		next if ($result =~ /Document draft.xml does not validate against rfc2629.dtd/);
		$line = undef;
		if ($result =~ s/^draft.xml:(\d+):/$1:/) {
			$line = $1;
		}
		print li(htmlify($result));
		if ($line) {
			print "<pre>";
			print sprintf("%4d: ", $line - 1), htmlify($draft[$line - 2]);
			print sprintf("%4d: ", $line), '<span style="color:red">', htmlify($draft[$line - 1]), '</span>';
			print sprintf("%4d: ", $line + 1), htmlify($draft[$line]);
			print "</pre>";
		}
	}
	print "</ul>\n"; #XXX
}
	print li("...validation failed");
} else {
	print li("Validation succeeded");
}
print li("Performing additional checks...");
# xsltproc args: --catalogs: uses catalog to expand local bibxml files
@additional = `/usr/local/bin/xsltproc --catalogs /home/fenner/public_html/ietf/xml2rfc-valid/additional-checks.xslt draft.xml 2>&1`;
if (@additional) {
	printres(@additional);
	#print ul(li([map {htmlify($_)} @additional]));
}
print li("...done");
print "\n", end_html,"\n";

if (!$cleanup) {
	chmod(0755, $d);
}

sub htmlify($) {
	my($line) = shift;

	$line =~ s/&/\&amp;/g;
	$line =~ s/</\&lt;/g;
	$line =~ s/>/\&gt;/g;

	$line;
}

sub preserve($) {
	my($line) = shift;

	$line =~ s/ /\&nbsp;/g;
	tt($line);
}

sub printres(@) {
	my(@results) = @_;

	print p("note: &lt;?rfc include?&gt; processing may have shifted line numbers") if ($has_rfcincludes);
	print "<ul>\n";	#XXX
	#
	# read in file - note that the <?rfc include=?> processing
	# may have modified it from what was uploaded
	open(DRAFT, "draft.xml") || die "draft.xml: $!\n";
	@draft = <DRAFT>;
	close(DRAFT);
	for ($i = 0; $i <= $#results; $i++) {
		$result = $results[$i];
		chomp($result);
		# generic failure message which can include ID/IDREF mismatch
		# so since we've got our own failure message, skip this one.
		next if ($result =~ /Document draft.xml does not validate against rfc2629.dtd/);
		if ($result =~ /failed to load external entity/) {
			if ($result =~ /rfc2629bis/) {
				$result .= " (you should probably just use rfc2629.dtd)";
			} else {
				$result .= " (Bill wants to know about this error so he can give more information about why it happened)";
			}
		}
		$line = undef;
		if ($result =~ s/^(draft.xml:)?(\d+):/$2:/) {
			$line = $2;
		}
		if ($line) {
			print li(htmlify($result));
			print "<pre>";
			if ($line > 1) {
				print sprintf("%4d: ", $line - 1), htmlify($draft[$line - 2]);
			}
			if ($line > 0) {
				print sprintf("%4d: ", $line), span({style => 'color:red'}, htmlify($draft[$line - 1]));
				if ($draft[$line - 1] eq $results[$i + 1]) {
					$i++;
					if ($results[$i + 1] =~ /\^/) {
						print "      ", span({style => 'color:red'}, htmlify($results[++$i]));
					}
				}
			}
			print sprintf("%4d: ", $line + 1), htmlify($draft[$line]);
			print "</pre>";
		} else {
			if ($result =~ /^\S+:\d+:/) {
				# an error report for a different document
				# (e.g., external entity)
				print li(htmlify($result));
			} else {
				# to do: if we printed the lines
				#  from this report already, then
				#  skip the copy from xmllint?
				# a line from the document being reported
				# so preserve space
				print li({style => 'list-style: none; color: red;'},preserve(htmlify($result)));
			}
		}
	}
	print "</ul>\n"; #XXX
}
