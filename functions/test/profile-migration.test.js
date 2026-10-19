const test = require("node:test");
const assert = require("node:assert/strict");

const {
  normalizeLegacyProfile,
} = require("../lib/profile-migration");

test("migration keeps only bounded profile fields", () => {
  const profile = normalizeLegacyProfile({
    nome: "  Maria  ",
    telefone: "1".repeat(31),
    endereco: "Rua A",
    unknownAdmin: true,
    always_listening_enabled: true,
  });

  assert.equal(profile.nome, "Maria");
  assert.equal(profile.endereco, "Rua A");
  assert.equal(profile.always_listening_enabled, true);
  assert.equal("telefone" in profile, false);
  assert.equal("unknownAdmin" in profile, false);
});

test("migration deduplicates and bounds caregiver identities", () => {
  const profile = normalizeLegacyProfile({
    supervisorId: "caregiver-a",
    caregiverIds: [
      "caregiver-a",
      "caregiver-a",
      "caregiver-b",
      "invalid/id",
    ],
    caregiverRoles: {
      "caregiver-a": "primary",
      "caregiver-b": "family",
      "invalid/id": "primary",
    },
    status: "active",
  });

  assert.deepEqual(profile.caregiverIds, ["caregiver-a", "caregiver-b"]);
  assert.equal(profile.supervisorId, "caregiver-a");
  assert.deepEqual(profile.caregiverRoles, {
    "caregiver-a": "primary",
    "caregiver-b": "family",
  });
  assert.equal(profile.status, "active");
});

test("migration cannot preserve an unlinked supervisor", () => {
  const profile = normalizeLegacyProfile({
    supervisorId: "invalid/id",
    caregiverIds: [],
    caregiverRoles: {"invalid/id": "primary"},
    status: "active",
  });

  assert.deepEqual(profile.caregiverIds, []);
  assert.deepEqual(profile.caregiverRoles, {});
  assert.equal(profile.supervisorId, null);
  assert.equal(profile.status, "pending");
});

test("migration preserves only valid routing entries", () => {
  const profile = normalizeLegacyProfile({
    supervisorId: "caregiver-a",
    caregiverIds: ["caregiver-a", "caregiver-b"],
    caregiverRouting: {
      "caregiver-a": {
        priority: 1,
        availableStart: "08:00",
        availableEnd: "18:00",
        alertTypes: ["help_request", "help_request", "unknown"],
        updatedBy: "caregiver-a",
      },
      "caregiver-b": {
        priority: 99,
        availableStart: "08:00",
        availableEnd: "18:00",
        alertTypes: ["low_stock"],
      },
      "outsider": {
        priority: 2,
        availableStart: "08:00",
        availableEnd: "18:00",
        alertTypes: ["low_stock"],
      },
    },
  });

  assert.deepEqual(profile.caregiverRouting, {
    "caregiver-a": {
      priority: 1,
      availableStart: "08:00",
      availableEnd: "18:00",
      alertTypes: ["help_request"],
      updatedBy: "caregiver-a",
    },
  });
});

test("migration enforces numeric ranges and valid status", () => {
  const profile = normalizeLegacyProfile({
    idade: 131,
    alex_voice_rate: 0.8,
    alex_voice_pitch: 3,
    status: "administrator",
  });

  assert.equal("idade" in profile, false);
  assert.equal(profile.alex_voice_rate, 0.8);
  assert.equal("alex_voice_pitch" in profile, false);
  assert.equal(profile.status, "pending");
});
