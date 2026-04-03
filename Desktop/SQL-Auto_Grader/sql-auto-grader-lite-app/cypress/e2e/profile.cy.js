describe('Profile Page', () => {
  beforeEach(() => {
    cy.loginAsStudent();
    cy.visit('/dashboard/profile');
  });

  it('loads profile page', () => {
    cy.url().should('include', '/dashboard/profile');
  });

  it('shows user profile information', () => {
    cy.contains('Profile').should('be.visible');
  });
});
