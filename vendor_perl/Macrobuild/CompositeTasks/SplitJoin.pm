# 
# A build Task that first runs a splitting task, then two or more parallel tasks,
# and then a joining Task.
#
# This file is part of Macrobuild.
# (C) 2014 Johannes Ernst
#
# Macrobuild is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Macrobuild is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Macrobuild.  If not, see <http://www.gnu.org/licenses/>.
#

use strict;
use warnings;

package MacroBuild::CompositeTasks::SplitJoin;

use base qw( MacroBuild::Task );
use fields qw( splitTask parallelTasks joinTask );

use Macrobuild::Logging;

##
# Run this task.
# $run: the inputs, outputs, settings and possible other context info for the run
sub run {
    my $self = shift;
    my $run  = shift;

    my $ret      = 0;
    my $continue = 1;

    my $in       = $run->taskStarting( $self );
    my $nextIn   = $in;

    my $splitTask = $self->{splitTask};
    if( $splitTask ) {
        my $childRun = $run->createChildRun( $in );
        my $taskRet  = $splitTask->run( $childRun );

        if( $taskRet ) {
            if( $taskRet < 0 ) {
                $ret = $taskRet;
                if( $self->{stopOnError} ) {
                    error( "ERROR when executing " . $splitTask->name() . ". Stopping." );
                    $continue = 0;
                }
            } else { # >0
                if( $ret == 0 ) { # first one
                    $ret = $taskRet;
                }
            }
        }
        $nextIn = $childRun->getOutput();
    }

    if( $continue ) {
        my $outData = {};
        while( my( $taskName, $task ) = each %{$self->{parallelTasks}} ) {
            my $childRun = $run->createChildRun( $nextIn->{$taskName} );

            my $taskRet = $task->run( $childRun );

            if( $taskRet ) {
                if( $taskRet < 0 ) {
                    $ret = $taskRet;
                    if( $self->{stopOnError} ) {
                        error( "ERROR when executing " . $task->name() . ". Stopping." );
                        $continue = 0;
                        last;
                    }
                } else { # >0
                    if( $ret == 0 ) { # first one
                        $ret = $taskRet;
                    }
                }
            }
            $outData->{$taskName} = $childRun->getOutput();
        }

        $nextIn = $outData;
    }
    if( $continue ) {
        my $joinTask = $self->{joinTask};
        if( $joinTask ) {
            my $childRun = $run->createChildRun( $nextIn );
        
            my $taskRet = $joinTask->run( $childRun );

            if( $taskRet ) {
                if( $taskRet < 0 ) {
                    $ret = $taskRet;
                    if( $self->{stopOnError} ) {
                        error( "ERROR when executing " . $joinTask->name() . ". Stopping." );
                        $continue = 0;
                    }
                } else { # >0
                    if( $ret == 0 ) { # first one
                        $ret = $taskRet;
                    }
                }
            }
            $nextIn = $childRun->getOutput();
        }
    }

    $run->taskEnded( $self, $nextIn );

    return $ret;
}

##
# Set the settings object
sub setSettings {
    my $self        = shift;
    my $newSettings = shift;

    foreach my $t ( values %{$self->{parallelTasks}}, $self->{splitTask}, $self->{joinTask} ) {
        if( $t ) {
            $t->setSettings( $newSettings );
        }
    }
}    

1;
