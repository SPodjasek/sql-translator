package SQL::Translator::Parser::XML::XMI;

# -------------------------------------------------------------------
# $Id: XMI.pm,v 1.6 2003-09-16 16:29:49 grommit Exp $
# -------------------------------------------------------------------
# Copyright (C) 2003 Mark Addison <mark.addison@itn.co.uk>,
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation; version 2.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA
# 02111-1307  USA
# -------------------------------------------------------------------

=head1 NAME

SQL::Translator::Parser::XML::XMI - Parser to create Schema from UML
Class diagrams stored in XMI format.

=head1 SYNOPSIS

  use SQL::Translator;
  use SQL::Translator::Parser::XML::XMI;

  my $translator     = SQL::Translator->new(
      from           => 'XML-XMI',
      to             => 'MySQL',
      filename       => 'schema.xmi',
      show_warnings  => 1,
      add_drop_table => 1,
  );

  print $obj->translate;

=head1 DESCRIPTION

Currently pulls out all the Classes as tables.

Any attributes of the class will be used as fields. The datatype of the
attribute must be a UML datatype and not an object, with the datatype's name
being used to set the data_type value in the schema.

=head2 XMI Format

The parser has been built using XMI 1.2 generated by PoseidonUML 2beta, which
says it uses UML 2. So the current conformance is down to Poseidon's idea
of XMI!

It should also parse XMI 1.0, such as you get from Rose, but this has had
little testing!

=head1 ARGS

=over 4

=item visibility

 visibilty=public|protected|private

What visibilty of stuff to translate. e.g when set to 'public' any private
and package Classes will be ignored and not turned into tables. Applies
to Classes and Attributes.

If not set or false (the default) no checks will be made and everything is
translated.

=back

=cut

# -------------------------------------------------------------------

use strict;

use vars qw[ $DEBUG $VERSION @EXPORT_OK ];
$VERSION = sprintf "%d.%02d", q$Revision: 1.6 $ =~ /(\d+)\.(\d+)/;
$DEBUG   = 0 unless defined $DEBUG;

use Data::Dumper;
use Exporter;
use base qw(Exporter);
@EXPORT_OK = qw(parse);

use base qw/SQL::Translator::Parser/;  # Doesnt do anything at the mo!
use SQL::Translator::Utils 'debug';
use SQL::Translator::XMI::Parser;


# SQLFairy Parser
#-----------------------------------------------------------------------------

# is_visible - Used to check visibility in filter subs
{
    my %vislevel = (
        public => 1,
        protected => 2,
        private => 3,
    );

    sub is_visible {
		my ($nodevis, $vis) = @_;
        $nodevis = ref $_[0] ? $_[0]->{visibility} : $_[0];
        return 1 unless $vis;
        return 1 if $vislevel{$vis} >= $vislevel{$nodevis};
        return 0; 
    }
}

sub parse {
    my ( $translator, $data ) = @_;
    local $DEBUG  = $translator->debug;
    my $schema    = $translator->schema;
    my $pargs     = $translator->parser_args;
    
    eval {
        
    debug "Visibility Level:$pargs->{visibility}" if $DEBUG;

    my $xmip = SQL::Translator::XMI::Parser->new(xml => $data);

    # TODO
    # - Options to set the initial context node so we don't just
    #   blindly do all the classes. e.g. Select a diag name to do.
    
    my $classes = $xmip->get_classes(
        filter => sub {
            return unless $_->{name};
            return unless is_visible($_, $pargs->{visibility});
            return 1;
        },
        filter_attributes => sub {
            return unless $_->{name};
            return unless is_visible($_, $pargs->{visibility});
            return 1;
        },
    );
    
    debug "Found ".scalar(@$classes)." Classes: ".join(", ",
        map {$_->{"name"}} @$classes) if $DEBUG;
    debug "Classes:",Dumper($classes);
    #print "Classes:",Dumper($classes),"\n";

	#
	# Turn the data from get_classes into a Schema
	#
	# TODO This is where we will applie different strategies for different UML
	# data modeling profiles.
	#
	foreach my $class (@$classes) {
        # Add the table
        debug "Adding class: $class->{name}" if $DEBUG;
        my $table = $schema->add_table( name => $class->{name} )
            or die "Schema Error: ".$schema->error;

        #
        # Fields from Class attributes
        #
        foreach my $attr ( @{$class->{attributes}} ) {
			my %data = (
                name           => $attr->{name},
                data_type      => $attr->{datatype},
                is_primary_key => $attr->{stereotype} eq "PK" ? 1 : 0,
                #is_foreign_key => $stereotype eq "FK" ? 1 : 0,
            );
			$data{default_value} = $attr->{initialValue}
				if exists $attr->{initialValue};

            debug "Adding field:",Dumper(\%data);
            my $field = $table->add_field( %data ) or die $schema->error;

            $table->primary_key( $field->name ) if $data{'is_primary_key'};
            #
            # TODO:
            # - We should be able to make the table obj spot this when
            #   we use add_field.
            #
        }

    } # Classes loop
    
    };
    print "ERROR:$@" if $@;

    return 1;
}

1;


=pod

=head1 BUGS

Seems to be slow. I think this is because the XMI files can get pretty
big and complex, especially all the diagram info, and XPath needs to load the
whole tree.

=head1 TODO

B<field sizes> Don't think UML does this directly so may need to include
it in the datatype names.

B<table_visibility and field_visibility args> Seperate control over what is 
parsed, setting visibility arg will set both.

Everything else! Relations, fkeys, constraints, indexes, etc...

=head1 AUTHOR

Mark D. Addison E<lt>mark.addison@itn.co.ukE<gt>.

=head1 SEE ALSO

perl(1), SQL::Translator, XML::XPath, SQL::Translator::Producer::XML::SQLFairy,
SQL::Translator::Schema.

=cut


