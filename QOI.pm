#package Image::QOI::PP::QOI; 
package QOI;

use strict;
use warnings;

use feature 'say';

my $QOI_OP_DIFF  = 0x40; # 0100 0000
my $QOI_OP_LUMA  = 0x80; # 1000 0000
my $QOI_OP_RUN   = 0xc0; # 1100 0000
my $QOI_OP_RGB   = 0xfe; # 1111 1110
my $QOI_OP_RGBA  = 0xff; # 1111 1111
my $QOI_MAGIC   = 'qoif';# 716f 6966

my $INDEX_LENGTH = 64;

sub encode {
	my ($data, $desc) = @_;
	my @bytes;

	# TODO: param checking

	my $width = $desc->{width};
	my $height = $desc->{height};
	my $channels = $desc->{channels};
	my $colorspace = $desc->{colorspace};

	push @bytes, unpack 'C4', $QOI_MAGIC;
	push @bytes, unpack 'C4', pack 'N', $width;
	push @bytes, unpack 'C4', pack 'N', $height;
	push @bytes, $channels;
	push @bytes, $colorspace;

	my $run = 0;

	my @index = map { [0, 0, 0, 0] } 1 .. $INDEX_LENGTH;

	my @pixel = (0, 0, 0, 255);
	my @prev = @pixel;

	my $pixel_len = $width * $height * $channels;
	my $pixel_end = $pixel_len - $channels;

	for( my $pos = 0; $pos < $pixel_len; $pos += $channels ) {

		$pixel[0] = $data->[$pos];
		$pixel[1] = $data->[$pos + 1];
		$pixel[2] = $data->[$pos + 2];

		if( $channels == 4 ) {
			$pixel[3] = $data->[$pos + 3];
		}

		# Is this pixel the same as the last one?
		if( _compare_pixels( \@pixel, \@prev ) ) {
			$run++;

			# Have we reached the end of our run?
			if( $run == 62 or $pos == $pixel_end ) {
				push @bytes, $QOI_OP_RUN | ($run - 1);
				$run = 0;
			}
		}
		else {
			# Were we in a run? Let's end it
			if( $run > 0 ) {
				push @bytes, $QOI_OP_RUN | ($run - 1);
				$run = 0;
			}

			my $hash = ($pixel[0] * 3 + $pixel[1] * 5 + $pixel[2] * 7 + $pixel[3] * 11) % 64;

			# Does our pixel match one in our index?
			if( _compare_pixels( \@pixel, $index[$hash] ) ) {
				push @bytes, $hash;
			}
			else {
				@{ $index[$hash] } = @pixel;

				# Is the alpha the same?
				if( $pixel[3] == $prev[3] ) {
					my ($vr, $vg, $vb) = map { $pixel[$_] - $prev[$_] } 0 .. 2;
					my $vg_r = $vr - $vg;
					my $vg_b = $vb - $vg;

					if(
						$vr > -3 and $vr < 2 and
						$vg > -3 and $vg < 2 and
						$vb > -3 and $vb < 2
					) {
						push @bytes, $QOI_OP_DIFF | ($vr + 2) << 4 | ($vg + 2) << 2 | ($vb + 2);
					}
					elsif (
						$vg_r >  -9 and $vg_r <  8 and
						$vg   > -33 and $vg   < 32 and
						$vg_b >  -9 and $vg_b <  8
					) {
						push @bytes, $QOI_OP_LUMA     | ($vg   + 32);
						push @bytes, ($vg_r + 8) << 4 | ($vg_b +  8);
					}
					else {
						push @bytes, $QOI_OP_RGB;
						push @bytes, $pixel[0];
						push @bytes, $pixel[1];
						push @bytes, $pixel[2];
					}
				}
				else {
					push @bytes, $QOI_OP_RGBA;
					push @bytes, $pixel[0];
					push @bytes, $pixel[1];
					push @bytes, $pixel[2];
					push @bytes, $pixel[3];
				}
			}
		}
		@prev = @pixel;
	}

	push @bytes, (0) x 7, 1;

	return \@bytes;
}

sub decode {
	# TODO
}

sub _compare_pixels {
	my ($a, $b) = @_;
	for my $i ( 0 .. 3 ) {
		if( $a->[$i] != $b->[$i] ) {
			return 0;
		} 
	}
	return 1;
}

1;
