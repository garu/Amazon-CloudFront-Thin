package Amazon::CloudFront::Thin;
use strict;
use warnings;
use URI            ();
use URI::Escape    ();
use Carp           ();
use HTTP::Headers  ();
use HTTP::Request  ();
use Digest::SHA    ();

our $VERSION = '0.01';

sub new {
    my ($class, @extra) = @_;
    my $args;
    my $self = {};

    if (@extra == 1) {
        Carp::croak 'please provide a hash or hash reference to new()'
            unless ref $extra[0] eq 'HASH';
        $args = $extra[0];
    }
    else {
        Carp::croak 'please provide a hash or hash reference to new()'
            unless @extra % 2 == 0;
        $args = {@extra};
    }

    foreach my $key (qw(aws_access_key_id aws_secret_access_key distribution_id)) {
        if (exists $args->{$key}) {
            $self->{$key} = $args->{$key};
        }
        else {
            Carp::croak "argument '$key' missing on call to new()";
        }
    }
    bless $self, $class;
    my $ua = $args->{ua} || _default_ua();
    $self->ua($ua);

    return $self;
}

sub _default_ua {
    require LWP::UserAgent;
    my $ua = LWP::UserAgent->new(
        keep_alive => 10,
#        requests_redirectable => [qw(GET HEAD DELETE PUT)]
    );
    $ua->timeout(10);
    $ua->env_proxy;
    return $ua;
}

sub ua {
    my ($self, $ua) = @_;
    $self->{_ua} = $ua if ($ua);
    return $self->{_ua};
}

sub create_invalidation {
    my ($self, @paths) = @_;
    if (@paths == 1 && ref $paths[0] && ref $paths[0] eq 'ARRAY') {
        @paths = @{$paths[0]};
    }

    my $time = time;

    my $url = URI->new(
        'https://cloudfront.amazonaws.com/2015-04-17/distribution/'
        . $self->{distribution_id} . '/invalidation'
    );

    my $content = _create_xml_payload(\@paths, $time);

    my $http_headers = HTTP::Headers->new(
        'Content-Length' => length $content,
        'Content-Type'   => 'text/xml',
        'Host'           => $url->host,
    );
    $http_headers->date($time);

    $http_headers->header(
        Authorization => sprintf(
            'AWS %s:%s',
            $self->{aws_secret_access_key},
            _calculate_signature($url, $http_headers, $content)
        ),
    );

    my $request = HTTP::Request->new('POST', $url, $http_headers, $content);
    return $self->ua->request($request);
}

sub _calculate_signature {
    my ($url, $headers, $content) = @_;

    my $canonical_request = _create_canonical_request($url, $headers, $content);

    my $string_to_sign = _create_string_to_sign($headers, $canonical_request);
}

sub _create_canonical_request {
    my ($url, $headers, $content) = @_;

    # http://docs.aws.amazon.com/general/latest/gr/sigv4-create-canonical-request.html
    my @sorted_header_names = sort $headers->header_field_names();
    return
        "POST\n"
      . ($url->path || '/') . "\n\n"
      . join( "\n", map {
            lc($_) . ':' . $headers->header($_)
          } @sorted_header_names
      ) . "\n\n"
      . join(';' => map lc, @sorted_header_names) . "\n"
      . Digest::SHA::sha256_hex($content)
    ;
}

sub _create_string_to_sign {
    my ($headers, $canonical_request) = @_;

    my ($sec, $min, $hour, $day, $month, $year) = localtime $headers->date;
    $year  += 1900;
    $month += 1;

    return
        "AWS4-HMAC-SHA256\n"
      . sprintf("%d%02d%02dT%02d%02d%02dZ\n", $year, $month, $day, $hour, $min, $sec)
      . sprintf("%d%02d%02d/us-east-1/cloudfront/aws4_request\n", $year, $month, $day)
      . Digest::SHA::sha256_hex($canonical_request)
    ;
}

sub _create_signature {
    my ($aws_secret_key, $string_to_sign, $date) = @_;

    return Digest::SHA::hmac_sha256_hex(
        $string_to_sign, Digest::SHA::hmac_sha256(
            'aws4_request', Digest::SHA::hmac_sha256(
                'cloudfront', Digest::SHA::hmac_sha256(
                    'us-east-1', Digest::SHA::hmac_sha256($date, 'AWS4' . $aws_secret_key)
                )
            )
        )
    );
}

sub _create_xml_payload {
    my ($paths, $identifier) = @_;
    my $total_paths = scalar @$paths;
    my $path_content;
    foreach my $path (@$paths) {
        # leading '/' is required:
        # http://docs.aws.amazon.com/AmazonCloudFront/latest/APIReference/InvalidationBatchDatatype.html
        $path = '/' . $path unless index($path, '/') == 0;
        # we wrap paths on CDATA so we don't have to escape them
        $path_content .= '<Path><![CDATA[' . $path . ']]></Path>'
    }
    return qq{<?xml version="1.0" encoding="UTF-8"?><InvalidationBatch xmlns="http://cloudfront.amazonaws.com/doc/2015-04-17/"><Paths><Quantity>$total_paths</Quantity><Items>$path_content</Items></Paths><CallerReference>$identifier</CallerReference></InvalidationBatch>};
}

__END__

=head1 NAME

Amazon::CloudFront::Thin - A thin, lightweight, low-level Amazon CloudFront client

=head1 SYNOPSIS

    use Amazon::CloudFront::Thin;

    my $cloudfront = Amazon::CloudFront::Thin->new({
        aws_access_key_id     => $key_id,
        aws_secret_access_key => $access_key,
        distribution_id       => 'my-cloudfront-distribution',
    });

    my $res = $cloudfront->create_invalidation(
       '/path/to/some/object.jpg',
       '/path/to/another/object.bin',
    );

=head1 DESCRIPTION

Amazon::CloudFront::Thin is a thin, lightweight, low level client for Amazon CloudFront.

It is designed for only ONE purpose: send a request and get a response.

It offers the following features:

=over 4

=item Low Level

Every request returns an L<HTTP::Response> object so you can easily inspect
what's happening inside, and can handle errors as you like.

=item Low Dependency

It has very few dependencies, so installation is easy and bloat-free
for your application. Aside from core modules like Digest::SHA, we
only rely on basic web modules like URI and HTTP::Message, which
you're probably already loaded from within your preferred web framework
or application.

=item Low Learning Cost

The interface is designed to follow Amazon CloudFront's official REST APIs.
So it is easy to learn and use by following the official documentation.

=back

=head2 Comparison to alternative modules

There are several useful modules for CloudFront on CPAN, like
L<Paws::CloudFront>, who provide a nice interface. You are welcome
to check them out to see if they suit your needs best. The reason
I wrote Amazon::CloudFront::Thin is because I needed to invalidate
CloudFront paths quickly and easily, and the alternatives felt either
like an "all or nothing" approach or lacked the documentation or
features I needed.

=head2 Amazon CloudFront setup in a Nutshell

Amazon CloudFront is the content-delivery (CDN) service of Amazon Web
Services (AWS). You use it by
L<< creating distributions|https://console.aws.amazon.com/cloudfront/home?region=us-east-1#distributions: >>
(each with its own "distribution id" which we use below). To manage
your distributions with this module, you need to provide credentials
allowed to access/change your CloudFront distributions. You do this
by going to L<< AWS's Identity and Access Management (IAM) console|https://console.aws.amazon.com/iam/home >>
and creating a new user. When you do that, the user's C<Access Key ID>
and C<Secret Access Key> credentials will be shown to you. You'll also
need to pass those to Amazon::CloudFront::Thin's constructor as shown
in the SYNOPSIS and below, as C<aws_access_key_id> and
C<aws_secret_access_key>, respectively. Finally, please note that
B<the provided IAM credentials must have the rights to change your CloudFront>.
You can do that by clicking on the user (in the Amazon IAM console where
you created it) and attaching a policy to it, such as the
C<CloudFrontFullAccess> standard policy. Otherwise you'll get errors when
trying to invalidate your CloudFront distributions.

=head1 CONSTRUCTOR

=head2 new( \%params )

B<Receives>: hashref with options.

B<Returns>: Amazon::CloudFront::Thin object.

    use Amazon::CloudFront::Thin;
    use IO::Socket::SSL;
    use Furl;

    
    my $cloudfront = Amazon::CloudFront::Thin->new(
        aws_access_key_id     => 'my_key_id',
        aws_secret_access_key => 'my_key_secret',
        distribution_id       => 'my-cloudfront-distribution-id',

        # optional
        ua => Furl->new(
            ssl_opts => { SSL_verify_mode => SSL_VERIFY_PEER()
        },
    );


Available arguments are:

=over

=item * C<aws_access_key_id> (B<required>)
Your CloudFront credential key id.

=item * C<aws_secret_access_key> (B<required>)
Your CloudFront credential secret.

=item * C<distribution_id> (B<required>)
The id of the CloudFront distribution you want to manage. 

=item * C<ua> (Optional)
An LWP::UserAgent compatible object (otherwise, LWP::UserAgent will be used).
The object must provide a C<request()> method that receives an HTTP::Request
and returns a response. The responses, whatever they are, will be forwarded
to your call. Also, the object must be able to handle B<HTTPS>. If you don't
want to use LWP::UserAgent, there is a (highly incomplete) list of
alternatives below:

Compatible: L<Furl>, L<LWP::UserAgent>, L<HTTP::Thin>, L<WWW::Curl::Simple>.

Incompatible: L<HTTP::Lite>, L<Hijk>, L<HTTP::Lite>, L<HTTP::Tiny>.

=back

=head1 ACCESSORS

=head2 ua

Gets/Sets the current user agent object doing the requests to Amazon
CloudFront. Defaults to LWP::UserAgent. You can replace it either
using this accessor or during object construction (see above for an
example that loads C<Furl> instead of C<LWP::UserAgent>).

=head1 METHODS

=head2 create_invalidation( $path )

=head2 create_invalidation( @paths )

=head2 create_invalidation( \@paths )

B<Receives>: list of strings (or arrayref of strings), each specifying
a different path to invalidate.

B<Returns>: an L<HTTP::Response> object for the request. Use the C<content()>
method on the returned object to read the contents:

    my $res = $cloudfront->create_invalidation( '/path/to/some/object.png' );

    if ($res->is_success) {
        my $content = $res->content;
    }

This method creates a new invalidation batch request on Amazon CloudFront.
Please note that B<paths are case sensitive> and that
B<the leading '/' is optional>, meaning C<"foo/bar"> and C<"/foo/bar">
point to the same object. Finally, please notice
B<you must escape all non-ASCII and unsafe characters yourself>. Do not
URL-encode any other characters in the path, or CloudFront will not
invalidate the old version of the updated object. We recommend using
L<URI::Escape> for this, like so:

    use URI::Escape qw( uri_escape );

    my @escaped_paths = map { uri_escape($_) } @original_paths;

    my $res = $cloudfront->create_invalidation( @escaped_paths );

For more information, please refer to
L<< Amazon's API documentation for CreateInvalidation|http://docs.aws.amazon.com/AmazonCloudFront/latest/APIReference/CreateInvalidation.html >>.
For information on invalidations in general, including limitations,
please refer to L<< Amazon's CloudFront Developer Guide|http://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/Invalidation.html >>.
Finally, please refer to L<< Amazon's CloudFront error messages|

=head1 AUTHOR

Breno G. de Oliveira C<< garu at cpan.org >>

=head1 LICENSE AND COPYRIGHT

Copyright 2015 Breno G. de Oliveira C<< <garu at cpan.org> >>. All rights reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. See L<perlartistic>.


=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.
