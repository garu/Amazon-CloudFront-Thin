### Amazon::CloudFront::Thin ###

This module provides a thin, lightweight, low-level Amazon CloudFront
client for Perl 5.

It is designed for only ONE purpose: send a request and get a response,
and it tries to conform with Amazon's own API.

#### Basic Usage

    use Amazon::CloudFront::Thin;

    my $cloudfront = Amazon::CloudFront::Thin->new({
        aws_access_key_id     => $key_id,
        aws_secret_access_key => $access_key,
        distribution_id       => 'my-cloudfront-distribution',
    });

    my $cloudfront->create_invalidation(
       '/path/to/some/object.jpg',
       '/path/to/another/object.bin',
    );

For more information, please refer to the
[Amazon::CloudFront::Thin's complete documentation](https://metacpan.org/pod/Amazon::CloudFront::Thin).

#### Installation

    cpanm Amazon::CloudFront::Thin

