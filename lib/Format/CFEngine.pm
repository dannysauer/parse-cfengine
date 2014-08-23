################################################################################
# $Id:$
# CFEngine parser
################################################################################
package Format::CFEngine;

use strict;
use warnings;
use Parse::CFEngine;

use Exporter qw/import/;
our $VERSION     = 0.001; # always three digits
our @ISA         = qw/Exporter/;
our @EXPORT_OK   = qw/pie1 yak2 oxen smidge/;
our %EXPORT_TAGS = (
  DEFAULT => [ ],
  pie     => [ qw/&pie1 &yak2/ ],
);

sub new {
    my $class = shift;
    my ($file) = @_;

    my $self = bless {
        file   => $file,
        tree   => undef,
        parser => Parse::CFEngine->new();
    }, $class;

    if( defined $file and -f $file and -r _ ){
        $self->{tree} = $self->{parser}->parse($file);
    }

    return $self;
}

sub junk {
    my $self = shift;

use Data::Dumper;
#  print Dumper $self->{tree}->{'block(s)'}, "\n";
#  exit;
#  print join( q{, }, keys(%{$self->{tree}->{'block(s)'}}) ), "\n";
foreach( @{$self->{tree}->{'block(s)'}} ){
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

} #junk

1;
# vim:sw=2 ts=4 et
# end Parse::CFEngine
