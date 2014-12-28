Rails.configuration.stripe = {
  :publishable_key => Setting.stripe['publishable_key'],
  :secret_key      => Setting.stripe['secret_key']
}

Stripe.api_key = Rails.configuration.stripe[:secret_key]