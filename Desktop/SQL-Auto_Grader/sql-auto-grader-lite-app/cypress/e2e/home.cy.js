describe('Home Page', () => {
  it('loads and shows navigation links', () => {
    cy.visit('/');
    cy.contains('Login').should('be.visible');
    cy.contains('Register').should('be.visible');
  });

  it('navigates to login page', () => {
    cy.visit('/');
    cy.contains('Login').click();
    cy.url().should('include', '/login');
  });

  it('navigates to register page', () => {
    cy.visit('/');
    cy.contains('Register').click();
    cy.url().should('include', '/register');
  });
});
