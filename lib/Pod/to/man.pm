# Pod::to::man - convert Perl 6 documentation to *roff manual

use Pod::Parser;

class Pod::to::man is Pod::Parser
{
    has Str  $!docname;         # file name with .pl or .pm removed
    has Str  $!prefix;          # characters that must be output before content
    has Bool $!undertext;       # true when line above has text
    has      $!manfile;         # file handle for output

    # used by perldoc to redirect output from $*OUT to a temp file.
    method set_manfile( $file ) { $!manfile = $file; }

    method doc_beg( Str $name ) {
        $!margin_R       = 75;
        $!prefix         = '';
        $!buf_out_enable = Bool::True;
        $!needspace      = Bool::False;
        $!undertext      = Bool::False;
        $!docname        = $name;        # default entire filename
        if $!docname ~~ /(.+)<dot>p<[lm]>$/ { $!docname = ~ $0; } # drop extension
        if defined( $!manfile ) { $!outfile = $!manfile; } # $!outfile is a member of Pod6Parser
        my $docdate = docdate( int(time) ); # TODO: replace with mtime when stat() works
        self.emit( ".TH $!docname 6 \"$docdate\" \"Perl 6\" \"Plain Old Documentation\"" );
        self.emit( ".nh"   ); # no hyphenation (broken words look ugly)
        self.emit( ".ad l" ); # adjust left (ragged right margin)
    }

    multi method blk_beg( PodBlock $podblock ) {
        my Str $typename = $podblock.typename;
        self.buf_flush;
        $!needspace = Bool::False;
        given $typename {
            when 'code' {
                if $!undertext { self.emit( '.sp' ); }   # sp downwards
                self.emit( '.nf' );                      # no-fill mode
            }
            when 'head' {
                my $level = $podblock.config<level>;
                if $level == 1 { $!prefix ~= '.SH '; } # section heading
                else { $!prefix ~= '.SS '; }        # section subheading
            }
            when 'para' {
                if not $!codeblock { self.emit( '.PP' ); }  # paragraph
            }
            when 'pod'     { }
            when 'comment' { }
            default {
                self.emit( ".\\\" unhandled block typename=$typename" );
            }
        }
    }

    multi method blk_beg( $refblock ) {
        my Str $typename = $refblock<typename>;
        self.buf_flush;
        $!needspace = Bool::False;
        given $typename {
            when 'code' {
                if $!undertext { self.emit( '.sp' ); }    # sp downwards
                self.emit( '.nf' );                       # no-fill mode
            }
            when 'head' {
                my $level = $refblock<config><level>;
                if $level == 1 { $!prefix ~= '.SH '; } # section heading
                else { $!prefix ~= '.SS '; }        # section subheading
            }
            when 'para' {
                if not $!codeblock { self.emit( '.PP' ); }   # paragraph
            }
            when 'pod'     { }
            when 'comment' { }
            default {
                self.emit( ".\\\" unhandled block typename=$typename" );
            }
        }
    }

    method fmt_beg( $refblock ) {
        my $typename = $refblock<typename>;
        $!needspace=Bool::False;
        given $typename {                   # S26 meaning  render
            when 'B' { $!prefix ~= '\fB'; } # basis        bold
            when 'D' { $!prefix ~= '\fI'; } # definition   italic
            when 'L' {                      # link         link
                       my Str $alt      = ~ $refblock<config><alternate>;
                       my Str $scheme   = ~ $refblock<config><scheme>;
                       my Str $external = ~ $refblock<config><external>;
                       my Str $internal = ~ $refblock<config><internal>;
                       my $link;
                       if $external ne '' and $internal ne '' {
                           $link = "$external#$internal";
                       }
                       else {
                           $link = "$external$internal";
                       }
                       given $scheme {
                           when 'http' | 'https' {
                               $link = "$scheme:$link";
                           }
                       }
                       if $alt ne '' {
                           $link = "$alt ($link)";
                       }
                       $!needspace = Bool::False;
                       self.buf_print('\fI' ~ $link);
                       $!buf_out_enable = Bool::False;
                       $!needspace = Bool::False;
                     } 
            default {
                self.emit( ".\\\" unhandled format $typename begin" );
            }
        }
    }

    method content( $reftopblock, Str $content ) {
        self.buf_print( $!prefix ~ $content );
        if $!codeblock { self.buf_flush; }
        $!prefix    = '';
        $!undertext = Bool::True;
    }

    method fmt_end( $refblock ) {
        my Str $typename = $refblock<typename>;
        $!buf_out_enable = Bool::True;
        given $typename {
            when 'B' { $!needspace=Bool::False; self.buf_print('\fR'); $!needspace=Bool::False; } # basis
            when 'D' { $!needspace=Bool::False; self.buf_print('\fR'); $!needspace=Bool::True;  } # definition
            when 'L' { $!needspace=Bool::False; self.buf_print('\fR'); $!needspace=Bool::False; } # link
            default {
                self.emit( ".\\\" unhandled format $typename end" );
            }
        }
    }

    method blk_end( $refblock ) {
        my $typename = $refblock<typename>;
        self.buf_flush;
        given $typename {
            when 'code' {
                self.emit( '.fi' );     # fill mode on (means word wrap)
            }
            when 'head' { }
            when 'para' {
                $!undertext = Bool::True;
            }
            when 'pod'  { }
            default {
                self.emit( ".\\\" unhandled block typename=$typename" );
            }
        }
    }

    method doc_end {
        self.emit( '.\" ' ~ $!docname ~ ' end.' );
    }

    method ambient( Str $line ) {
    }

    sub docdate( Num $seconds ) {
        # Bogus year-month-day calculation.
        # Needs an accurate localtime() function to replace this kludge.
        my $day   = floor( $seconds / 3600 / 24 );
        my $year  = floor( $day / 365.24 ); $day -= floor( $year * 365.24 );
        my $month = floor( $day / 30.5 );   $day -= floor( $month * 30.5 );
        return sprintf( "%4d-%02d-%02d", $year+1970, $month+1, $day+1 );
    }
}
=begin pod

=head1 NAME
Pod::to::man - translate Plain Old Documentation (POD) to Unix man page

=head1 SYNOPSIS
pod2man in Perl 6 (Rakudo):
=begin code
#!/usr/local/bin/perl6
use v6;
use Pod::to::man;
my Pod::to::man $translator .= new;
$translator.parse_file( @*ARGS[0] );
=end code
perldoc in Perl 6 (Rakudo):
=begin code
#!/usr/local/bin/perl6
use v6;
use Pod::to::man;
if + @*ARGS == 0 {
    $*ERR.say( "usage: rakudoc <filename>" );
}
else {
    my Str $filename = @*ARGS[0];
    my Str $docname = $filename;
    $docname .= subst( / <dot> p<[lm]> $ /, {} ); # remove .pl, .pm suffixes
    $docname .= subst( / .* \/ /, {} ); # delete directory if exists before name
    my Str $tempfilename = "/tmp/rakudoc.$docname.temp";
    my Str $manprompt =
        "Perl 6 $docname line %lb ?Lof %L (?eEND:%Pb\\%.).";
    my Pod::to::man $parser .= new;
    my $tempfile = open( $tempfilename, :w );
    $parser.set_manfile( $tempfile );
    $parser.parse_file( $filename );
    $tempfile.close();
    run( "man --prompt=\"$manprompt\" $tempfilename" );
    unlink( $tempfilename );
}
=end code
or a shell command:
=begin code
perl6 -e'use Pod::to::man; Pod::to::man.new.parse_file(~ @*ARGS[0]);' lib/Pod/to/man.pm
=end code

=head1 DESCRIPTION
The perldoc shell script uses this L<doc:Pod::to::man> to create the
temporary nroff file displayed by the Unix L<man:man> command.

An attempt is being made to handle both Perl 6 and Perl 5 documentation.

=head1 BUGS
Translation of many formatting codes is incomplete.

Additional spaces are sometimes inserted around format codes on pod line
boundaries ($!needspace errors).

Code lines longer than 71 characters are wrapped and justified.

The document date (docdate) should be when the source file was last
edited. In the absence of stat() and localtime() functions, it is
currently an approximation of today's date.

L<RT#62030|http://rt.perl.org/rt3/Public/Bug/Display.html?id=62030> after
r34090 Rakudo -e ignores command line arguments for @*ARGS,
so the L<#SYNOPSIS> shell example above does not get the file name.

=head1 SEE ALSO
L<doc:Pod::Parser>, L<S26|http://perlcabal.org/syn/S26.html> (Perl 6 POD).

L<man:groff(7)> or L<man:groff(1)>,
or http://www.gnu.org/software/groff/manual/ (Unix man page format).

=end pod

