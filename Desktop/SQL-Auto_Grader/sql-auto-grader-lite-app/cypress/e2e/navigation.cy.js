describe("Navigation", () => {
  it("redirects unauthenticated user from /dashboard to /login", () => {
    cy.visit("http://localhost:3000/dashboard");
    cy.url().should("include", "/login");
  });

  it("navbar logo navigates to home", () => {
    cy.visit("http://localhost:3000/login");
    cy.get("nav").contains("SQL Practice Platform").click();
    cy.url().should("eq", "http://localhost:3000/");
  });

  it("About link works from navbar", () => {
    cy.visit("http://localhost:3000");
    cy.get("nav").contains("About").click();
    cy.url().should("include", "/about");
  });
});
