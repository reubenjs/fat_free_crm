class RegistrationObserver < ActiveRecord::Observer
  observe :registration
  include SaasuHandler
  
  def before_destroy(registration)
    i = Saasu::Invoice.find(registration.saasu_uid)
    if i.payments.present?
      Delayed::Worker.logger.add(
        Logger::INFO, 
        "Not deleting invoice for #{registration.contact.full_name} from saasu as it contains a payment."
        )
      UserMailer.delay.saasu_registration_error(registration.contact, "Invoice not deleted from Saasu as it contains payments. Manual entry required")
    else
      response = Saasu::Invoice.delete(registration.saasu_uid)
      if response.errors.nil?
        Delayed::Worker.logger.add(Logger::INFO, "Deleted invoice for #{registration.contact.full_name} from saasu.")
      else
        Delayed::Worker.logger.add(Logger::INFO, "Error deleting invoice for #{registration.contact.full_name} from saasu. #{response.errors}")
        UserMailer.delay.saasu_registration_error(registration.contact, response.errors[0].message)
      end
    end
  end
  
end