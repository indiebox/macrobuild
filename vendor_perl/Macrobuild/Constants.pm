#
# Definitions for running macrobuild.
#
# Copyright (C) 2017 and later, Indie Computing Corp. All rights reserved. License: see package.
#

use strict;
use warnings;

package Macrobuild::Constants;

use UBOS::Logging;

use base qw( Macrobuild::HasNamedValues );
use fields qw( name vars );
use overload q{""} => 'toString';

##
# Constructor
# $name: name of the settings object, in case there is more than one
# $vars: variables available to the tasks
# $resolver: where to go to for variables not found locally
sub new {
    my $self     = shift;
    my $name     = shift;
    my $vars     = shift || {};
    my $resolver = shift || undef;

    unless( ref $self ) {
        $self = fields::new( $self );
    }
    $self->SUPER::new( $resolver );

    $self->{name}     = $name;
    $self->{vars}     = $vars;

    return $self;
}

##
# Create a new Constants object by reading from a Perl file and delegating
# to the provided resolver. The file must be a Perl file and return a
# hash.
# $fileName: the file to read
# $resolver: where to go to for variables not found locally
# return the new Constants object
sub readAndCreate {
    my $self     = shift;
    my $fileName = shift;
    my $resolver = shift;

    my $vars = eval "require '$fileName';" || fatal( 'Cannot read file', "$fileName\n", $@ );

    return $self->new( 'Constants read from ' . $fileName, $vars, $resolver );
}

##
# Get name of this object, for debugging.
# return: name
sub getName {
    my $self = shift;

    return $self->{name};
}

##
# @Overridden
sub getValueOrDefault {
    my $self          = shift;
    my $name          = shift;
    my $default       = shift;
    my $getValueTrace = shift;

    if( defined( $getValueTrace )) {
        push @$getValueTrace, $self;
    }
    my $ret;

    if( exists( $self->{vars}->{$name} ) && defined( $self->{vars}->{$name} )) {
        $ret = $self->{vars}->{$name};

    } elsif( defined( $self->getResolver() )) {
        $ret = $self->getResolver()->getValueOrDefault( $name, $default, $getValueTrace );

    } else {
        $ret = $default;
    }
    return $ret;
}

##
# @Overridden
sub getLocalValueNames {
    my $self = shift;

    return keys %{$self->{vars}};
}

##
# Obtain all values of a named value, including overridden ones.
#
# $name: the name of the value
# $appendHere: append the values to this array, or create a new one
# return: array of the values, the first of which is the actual value. Others
#         are overridden values
sub getAllValues {
    my $self       = shift;
    my $name       = shift;
    my $appendHere = shift || [];

    if( exists( $self->{vars}->{$name} )) {
        my $value = $self->{vars}->{$name};
        push @{$appendHere}, $value;
    }
    my $resolver = $self->getResolver();
    if( defined( $resolver )) {
        $resolver->getAllValues( $name, $appendHere );
    }
    return $appendHere;
}

##
# Obtain all obtainable variables recursively, with all values, including
# overridden ones.
#
# $insertHere: insert the values into this hash, or create a new one
# return: hash of variable name to array of values, the first of which is the actual
#         value. Others are overridden values.
sub getAllNamedValuesWithAllValues {
    my $self       = shift;
    my $insertHere = shift || {};

    foreach my $key ( keys %{$self->{vars}} ) {
        my $value = $self->{vars}->{$key};
        unless( exists( $insertHere->{$key} )) {
            $insertHere->{$key} = [];
        }
        push @{$insertHere->{$key}}, $value;
    }
    my $resolver = $self->getResolver();
    if( $resolver ) {
        $resolver->getAllNamedValuesWithAllValues( $insertHere );
    }
    return $insertHere;
}

##
# Convert to string
# return string
sub toString {
    my $self = shift;

    my $ret = overload::StrVal( $self ) . '( name="' . $self->getName();
    $ret .= '" )';
    return $ret;
}

1;
