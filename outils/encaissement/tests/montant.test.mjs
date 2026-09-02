import { test } from "node:test";
import assert from "node:assert/strict";
import { centimesDepuisSaisie as c, formaterCentimes as f, formaterDuree as d, secondesRestantes as s } from "../src/lib/montant.ts";

test("les saisies légitimes", () => {
  assert.equal(c("12,50"), 1250);
  assert.equal(c("12.50"), 1250);
  assert.equal(c("12"), 1200);
  assert.equal(c("0,01"), 1);
  assert.equal(c("  7,05  "), 705);
  assert.equal(c("12,5"), 1250);     // une seule décimale = dizaines de centimes
  assert.equal(c("19,99"), 1999);
  assert.equal(c("999999,99"), 99999999);
});

test("les pièges du flottant", () => {
  // parseFloat("1.005") * 100 vaut 100.49999999999999 : arrondi, 100 centimes.
  assert.equal(c("1,00"), 100);
  assert.equal(c("8,10"), 810);      // 8.1 * 100 = 810.0000000000001
  assert.equal(c("29,70"), 2970);    // 29.7 * 100 = 2969.9999999999995
  assert.equal(c("70,70"), 7070);
});

test("les saisies à refuser", () => {
  for (const mauvais of ["", "  ", "0", "0,00", "-5", "abc", "12,505", "12,5,5",
                         "1 000", "12€", "1e3", "+12", ".50", "12."])
    assert.equal(c(mauvais), null, `« ${mauvais} » aurait dû être refusé`);
});

test("l'affichage", () => {
  assert.match(f(1250), /12,50/);
  assert.match(f(1250), /€/);
  assert.equal(d(137), "2:17");
  assert.equal(d(60), "1:00");
  assert.equal(d(9), "0:09");
  assert.equal(d(0), "0:00");
});

test("le compte à rebours ne passe jamais sous zéro", () => {
  const t = 1_000_000;
  assert.equal(s(t + 300_000, t), 300);
  assert.equal(s(t, t), 0);
  assert.equal(s(t - 90_000, t), 0);
});
