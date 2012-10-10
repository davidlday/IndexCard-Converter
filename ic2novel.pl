#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Long;
use XML::LibXML;
use RTF::Writer;
use Cwd 'abs_path';
use File::Basename;
use FileHandle;
use Lingua::EN::Fathom;

my $indexCardFile = '';
my $rtfFile = '';
my $msFormat = 'novel';
my $includeSynopsis = 0;
my $includeNotes = 0;
my $includeChapterTitles = 0;

my $opt = GetOptions(
    'icfile=s'  => \$indexCardFile,
    'rtffile=s' => \$rtfFile,
    'format=s'  => \$msFormat,
    'chtitles!' => \$includeChapterTitles,
    'synopsis!' => \$includeSynopsis,
    'notes!'    => \$includeNotes,
);


# TODO: Validate indexCardFile is a real file.

# Initialize Readability
my $fathom = Lingua::EN::Fathom->new();

# Load XML from IndexCard file.
my $parser = XML::LibXML->new();
my $dom = $parser->load_xml(
    location    => $indexCardFile,
);

# /plist/dict/key[text()='name']/following-sibling::*[1]/text()
my $msTitle = $dom->findvalue("/plist/dict/key[text()='name']/following-sibling::*[1]/text()");
my $msAuthorName = '';
my $msAuthorLN = '';
my $msAuthorInfo = '';
my $msChapters = '';
my $msChapterNum = 1;
my $msWordCount = 0;

my @indexCards = $dom->findnodes("/plist/dict/key[text()='cardList']/following-sibling::array[1]/dict");
foreach my $indexCard (@indexCards) {
    my $title = $indexCard->findvalue("./key[text()='title']/following-sibling::*[1]/text()");
    my $sortOrder = $indexCard->findvalue("./key[text()='sortOrder']/following-sibling::*[1]/text()");
    my $synopsis = $indexCard->findvalue("./key[text()='synopsis']/following-sibling::*[1]/text()");
    my $notes = $indexCard->findvalue("./key[text()='notes']/following-sibling::*[1]/text()");
    my $text = $indexCard->findvalue("./key[text()='text']/following-sibling::*[1]/text()");
    my $label = $indexCard->findvalue("./key[text()='label']/following-sibling::*[1]/text()");
    my $isStack = $indexCard->findvalue("name(./key[text()='stack']/following-sibling::*[1])");
    my $inDraft = $indexCard->findvalue("name(./key[text()='draft']/following-sibling::*[1])");
    my $relation = $indexCard->findvalue("./key[text()='relation']/following-sibling::*[1]/text()"); # Stack Name
    if ($title eq 'Author Info') {
        ($msAuthorName) = split('\n', $synopsis);
        my @namepts = split('\s', $msAuthorName);
        $msAuthorLN = pop(@namepts);
        $msAuthorInfo = $synopsis;
        chomp($msAuthorInfo);
        $msAuthorInfo =~ s/\n/\n\\par /g;
    } elsif ($inDraft eq 'true') {
        $fathom->analyse_block($text, 1);
        my $section_start = ($msChapterNum == 1) ? '{\sectd\sbkpage\pgnrestart' : '{\sectd\sbkpage';
        $section_start .= "\n" . '{\pard\fs24\sl480\slmult1\qc\sb4320 Chapter ' . $msChapterNum . '\par}' . "\n";
        if ($includeChapterTitles) { $section_start .= '{\pard\fs24\sl480\slmult1\qc ' . $title . '\par}' . "\n"; }
        $section_start .= '{\pard\fs24\sl480\slmult1\qc\par}' . "\n";
        $msChapters .= $section_start;
        my @chapterLines = split('\n', $text);
        my $sectionNum = 1;
        my $lineNum = 0;
        foreach my $line (@chapterLines) {
            $lineNum++;
            next if ($line eq '');
            if ($line ne '#') {
                $msChapters .= '{\pard\fs24\fi720\sl480\slmult1' . "\n$line\n" . '\par}';
            } elsif ($line eq '#') {
                $msChapters .= '{\pard\fs24\sl480\slmult1\qc#\par}';
            }
        }
        $msChapters .= '\sect}' . "\n";
         
        $msChapterNum++;
    }
}

# Readability Stats
my $num_chars             = $fathom->num_chars;
my $num_words             = $fathom->num_words;
my $percent_complex_words = $fathom->percent_complex_words;
my $num_sentences         = $fathom->num_sentences;
my $num_text_lines        = $fathom->num_text_lines;
my $num_blank_lines       = $fathom->num_blank_lines;
my $num_paragraphs        = $fathom->num_paragraphs;
my $syllables_per_word    = $fathom->syllables_per_word;
my $words_per_sentence    = $fathom->words_per_sentence;
my $fog     = $fathom->fog;
my $flesch  = $fathom->flesch;
my $kincaid = $fathom->kincaid;

print $fathom->report;

# Pring the RTF Document
my $rtf = FileHandle->new("> $rtfFile");
print $rtf '{\rtf1\ansi\deff0\margl1440\margr1440\margt1440\margb1440{\fonttbl{\f0 Courier New;}}{\sectd {\pard\ql\plain\f0\fs24';
print $rtf $msAuthorInfo;
print $rtf '\par}{\pard\fs24\sl480\slmult1\qc\sb4320 ';
print $rtf $msTitle;
print $rtf '\par}{\pard\fs24\sl480\slmult1\qc by ';
print $rtf $msAuthorName;
print $rtf ' \par}{\pard\qc\f0\sb5760 approximately ';
print $rtf $fathom->num_words;
print $rtf ' words\par}\sect}{\header\pard\qr\plain\f0\fs24 ';
print $rtf "$msAuthorLN  / $msTitle / ";
print $rtf '\chpgn\par}';
print $rtf $msChapters;
print $rtf '}';

exit;

