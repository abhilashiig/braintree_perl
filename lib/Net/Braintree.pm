package Net::Braintree;

use 5.006;
use strict;
use warnings;
use Net::Braintree::Address;
use Net::Braintree::AdvancedSearchFields;
use Net::Braintree::AdvancedSearchNodes;
use Net::Braintree::ApplePayCard;
use Net::Braintree::ClientToken;
use Net::Braintree::CreditCard;
use Net::Braintree::Customer;
use Net::Braintree::CustomerSearch;
use Net::Braintree::DisbursementDetails;
use Net::Braintree::Dispute;
use Net::Braintree::MerchantAccount;
use Net::Braintree::PartnerMerchant;
use Net::Braintree::PaymentMethod;
use Net::Braintree::PayPalAccount;
use Net::Braintree::PayPalDetails;
use Net::Braintree::ResourceCollection;
use Net::Braintree::SettlementBatchSummary;
use Net::Braintree::Subscription;
use Net::Braintree::SubscriptionSearch;
use Net::Braintree::Transaction;
use Net::Braintree::TransactionSearch;
use Net::Braintree::Disbursement;
use Net::Braintree::TransparentRedirect;
use Net::Braintree::WebhookNotification;
use Net::Braintree::WebhookTesting;
use Net::Braintree::Configuration;
use Net::Braintree::GraphQL;
use Net::Braintree::GraphQLGateway;

=head1 NAME

Net::Braintree - A Client Library for wrapping the Braintree Payment Services Gateway API with GraphQL support

=head1 VERSION

Version 1.0.0

=head1 NOTICE

This is a community-maintained fork of the original Braintree Perl SDK with added GraphQL API support.
This is NOT an official Braintree SDK and is not maintained by Braintree or PayPal.

The original Braintree Perl SDK is deprecated. This fork adds support for the new GraphQL APIs
while maintaining backward compatibility with existing code.

=cut

our $VERSION = '1.0.0';

my $configuration_instance = Net::Braintree::Configuration->new;

sub configuration { return $configuration_instance; }

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Net::Braintree


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Net-Braintree>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Net-Braintree>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Net-Braintree>

=item * Search CPAN

L<http://search.cpan.org/dist/Net-Braintree/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2011-2017 Braintree, a division of PayPal, Inc.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of Net::Braintree
