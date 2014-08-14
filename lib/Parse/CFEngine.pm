################################################################################
# $Id:$
# CFEngine parser
################################################################################
package Parse::CFEngine;
use IO::File;
use Parse::RecDescent;

#$::RD_HINT++;
#$::RD_WARN++;
#$::RD_TRACE++;

my $indent = q{ }x3; # indent sequence (You "can" use tab, but I suggest spaces)
my $level = 0;       # initial number of indents

my $p;
# this should probably be an external file
my $grammar = <<'END_OF_GRAMMAR';
<autotree>
cfengine:               block(s)

block:                 bundle typeid blockid bundlebody
                     | bundle typeid blockid usearglist bundlebody
                     | body typeid blockid bodybody
                     | body typeid blockid usearglist bodybody

bundle:                'bundle'

body:                  'body'

typeid:                /[a-z]+/

blockid:               /[a-zA-Z0-9_\-]+/

usearglist:            '('
                       aitem(s? /,/)
                       ')'

aitem:                 /[a-zA-Z0-9_]+/

bodybody:              '{'
                       bodyattrib(s)
                       '}'

bodyattrib:            class(?)
                       selection(s)

# maybe make this expression a tad smarter
class:                 /[a-zA-Z0-9_\!&\|\.\(\)]+::/

selection:             id
                       '=>'
                       rval
                       ';'

rval:                  qstring
                     | list
                     | usefunction
                     | nakedvar
                     | id

id:                    /[a-zA-Z0-9_]+/ # identifier
qstring:               /"(?:\\"|[^"])*"/ # 0 or more non-" chars or \"
                     | /'(?:\\'|[^'])*'/
                     | /`(?:\\`|[^`])*`/
                    #| /`[^`]*`/ # I forget if backticks can be escaped
nakedvar:              /\$[({][a-zA-Z0-9_]+[})]/ # $(var) or ${var}

list:                 '{'
                       litem(s? /,/)
                      /,?/ # trailing comma was a problem before this
                      '}'

litem:                 qstring
                     | nakedvar
                     | usefunction
                     | id # is this actually valid?

usefunction:           functionid givearglist(?)

functionid:            id
                     | nakedvar # I'm not sure about this, either

givearglist:           '('
                       gaitem(s? /,/)
                       ')'

gaitem:                qstring
                     | usefunction
                     | nakedvar
                     | id

bundlebody:            '{'
                       statement(s)
                       '}'

statement:             category
                       classpromise(s)

category:              /[a-zA-Z]+:/

classpromise:          class(?)
                       promise(s)

promise:               promiser
                       constraint(s? /,/)
                       ';'
                     | promiser
                       '->'
                       rval
                       constraint(s? /,/)
                       ';'

promiser:              qstring

constraint:            id
                       '=>'
                       rval
END_OF_GRAMMAR
; # I just can't leave the semicolon out

$p = Parse::RecDescent->new($grammar);
my $tree;
my $path = shift
  or die qq{Usage: $0 filename\n};
my $f = IO::File->new($path)
  or die qq{Failed opening '$path': $?\n};
#print join( q{}, grep(/\S/, map {s/#.*$//;$_;} $f->getlines )), "\n";
#die;
unless ( $tree = $p->cfengine(
  # delete comments, then only return non-whitespace lines
  join( q{}, 
        grep( /\S/, map {s/#.*$//;$_;} $f->getlines )
  )
) ){
  die qq{Failed parsing.\n};
}

#if (my $tree = $p->cfengine( q!
#    bundle agent kapow { type: "a" b=>c;
#                               x:: "c" d=>e, f=>g;
#                               "y" -> "k" ff=>gg;
#                         othertype: "x" y=>z;}
#    body common second  { c => d; d => c; }
#    body common turd  { type:: g => f;
#                        \!type:: g => fff; }
#    !)
#) {
if( $tree ){
  print "Ok! ($path)\n";
  use Data::Dumper;
#  print Dumper $tree->{'block(s)'}, "\n";
#  exit;
#  print join( q{, }, keys(%{$tree->{'block(s)'}}) ), "\n";
  foreach( @{$tree->{'block(s)'}} ){
    if($_->{bundle}){
      print $_->{typeid}->{__VALUE__}, " bundle named ", $_->{blockid}->{__VALUE__}, "\n";
      my $body = $_->{bundlebody}->{'statement(s)'};
      print "\t", scalar @$body, " statement types.\n";
      foreach my $s (@$body){
        print "\t\t", $s->{category}->{__VALUE__}, "\n";
        foreach my $p (@{$s->{'classpromise(s)'}} ){
          print "\t\t\t";
          if( @{$p->{'class(?)'}} ){
            print "(" . $p->{'class(?)'}->[0]->{__VALUE__} . ") ";
          }
          print scalar @{$p->{'promise(s)'}}, " promises\n";
        }
      }
    } 
    else{
      print $_->{typeid}->{__VALUE__}, " body named ", $_->{blockid}->{__VALUE__}, "\n";
      my $body = $_->{bodybody}->{'bodyattrib(s)'};
      foreach (@$body){
#print Dumper $_, "\n\n";
#print Dumper $_->{'selection(s)'}, "\n\n";
#next;
        print "\t";
        print scalar @{$_->{'selection(s)'}}, " attributes";
        if( @{$_->{'class(?)'}} ){
          print " (", $_->{'class(?)'}->[0]->{'__VALUE__'}, ")";
        }
        print "\n";
      }
      print q{body },
           $_->{typeid}->{__VALUE__},
           q{ },
           $_->{blockid}->{__VALUE__},
           $_->{bodybody}->{__STRING1__},
           qq{\n};
      foreach (@$body){
        $level = 1;

        if( @{$_->{'class(?)'}} ){
          print $indent x $level, $_->{'class(?)'}->[0]->{'__VALUE__'}, qq{\n};
          $level++;
        }

        # inside the body

        # get maximum parameter width
        my $width=0;
        foreach ( @{$_->{'selection(s)'}} ){
          $width = ( length($_->{id}->{'__VALUE__'}) > $width )
                   ? length($_->{id}->{'__VALUE__'})
                   : $width;
        }

        foreach ( @{$_->{'selection(s)'}} ){
          printf $indent x $level . "%-${width}.${width}s", $_->{id}->{'__VALUE__'};
          print q{ => };
          # rval could be any of qstring, list, usefunction, nakedvar, id

          my $rval;
          if(  $rval = $_->{'rval'}->{'qstring'}
            or $rval = $_->{'rval'}->{'nakedvar'}
            or $rval = $_->{'rval'}->{'id'}
          ){
            print $rval->{'__VALUE__'};
          }
          elsif( $rval = $_->{'rval'}->{'list'} ){
            print $rval->{'__STRING1__'}, q{ };
            my @items = ();
            foreach ( @{$rval->{'litem(s?)'}} ){
              # litem could be a qstring, nakedvar, or a usefunction
              my $litem;
              if(  $litem = $_->{'qstring'}
                or $litem = $_->{'nakedvar'}
              ){
                push( @items, $litem->{'__VALUE__'} )
              }
              elsif( $litem = $_->{'usefunction'} ){
                my $str = $litem->{'functionid'}->{'id'}->{'__VALUE__'};
                if( @{$litem->{'givearglist(?)'}} ){
                  # args to a function can be a function
                  # need a recursive "format function" method first...
                  warn "usefunction with givearglist not yet implemented";
                  #print Dumper $litem, "\n\n";
                }
                push( @items, $str );
              }
              else{
                die "Someone updated the grammar but forgot to update this";
              }
            }
            my $joinstring = q{, };
            if( length( join($joinstring, @items )) > 2 ){
              # this should be smarter; like taking the indent, width, and a mx total width
              # break the long list up with newlines
              $joinstring = qq{,\n} . $indent x ($level+1);
              print qq{\n}, $indent x ($level+1);
            }
            print join( $joinstring, @items );
            if( $joinstring =~ /\n/ ){
              print qq{,\n}, $indent x $level;
            }
            else{
              print q{ };
            }
            print $rval->{'__STRING2__'};
          }
          else{
print Dumper $_->{'rval'}, "\n\n";
#print Dumper $_->{'selection(s)'}, "\n\n";
next;
          }
          print qq{;\n};
        }
      }
      print $_->{bodybody}->{__STRING2__}, qq{\n\n};
    }
  }
}
else{
  print "Bad!\n";
  exit 1;
}

sub formatsub {
  my ($ilevel, $f) = @_;
  my $ret = q{};
  $ret .= $indent x $ilevel;
  $ret .= $f->{'functionid'}->{'id'}->{'__VALUE__'};
  if( @{$f->{'givearglist(?)'}} ){
                  #{'gaitem(s?)'}
                  #print Dumper $litem, "\n\n";
  }
}
