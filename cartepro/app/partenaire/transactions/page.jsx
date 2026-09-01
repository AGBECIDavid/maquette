import { Shell } from "../../../components/Shell.jsx";
import { PartnerSpace } from "../../../screens/Partner.jsx";

export const metadata = { title: "Transactions" };

export default function Page() {
  return <Shell><PartnerSpace section="transactions" /></Shell>;
}
