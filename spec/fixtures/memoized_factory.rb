class CustomersController
  def create
    @customer = provisioning_service.create_customer(params)
  end

  def show
    @customer = customer_repository.find(params[:id])
  end

  private

  def provisioning_service
    @provisioning_service ||= ProvisioningService.new(current_user)
  end

  def customer_repository
    @customer_repository ||= CustomerRepository.new
  end
end
